import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Publisher implements PluginRevocationAuditPublisher {
  final List<PluginRevocationAuditEvent> events = [];
  bool fail = false;

  @override
  Future<void> publish(PluginRevocationAuditEvent event) async {
    if (fail) throw StateError('offline');
    events.add(event);
  }
}

PluginRevocationExecutionRecord _pending() => PluginRevocationExecutionRecord(
  idempotencyKey: 'operation:plugin:provider:deactivate',
  operationId: 'operation',
  pluginId: 'plugin',
  providerOwnerId: 'provider',
  action: CapabilityImpactAction.deactivate,
  status: PluginRevocationExecutionStatus.requiresReconciliation,
  updatedAt: DateTime.utc(2026, 1, 1),
);

PluginRevocationExecutionRecord _completed() => PluginRevocationExecutionRecord(
  idempotencyKey: 'operation:plugin:provider:deactivate',
  operationId: 'operation',
  pluginId: 'plugin',
  providerOwnerId: 'provider',
  action: CapabilityImpactAction.deactivate,
  status: PluginRevocationExecutionStatus.completed,
  updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
);

void main() {
  group('InMemoryTransactionalPluginRevocationStore', () {
    test('commits terminal execution and outbox event together', () async {
      final store = InMemoryTransactionalPluginRevocationStore();
      expect(await store.writePending(_pending()), isTrue);
      await store.completeAndEnqueue(_completed());

      expect((await store.read(_pending().idempotencyKey))!.status,
          PluginRevocationExecutionStatus.completed);
      final messages = await store.snapshot();
      expect(messages, hasLength(1));
      expect(messages.single.state, PluginRevocationOutboxState.pending);
      expect(messages.single.event.outcome, 'completed');
      expect(messages.single.event.operationId, 'operation');
    });

    test('event ID is unique and repeated enqueue is idempotent', () async {
      final store = InMemoryTransactionalPluginRevocationStore();
      await store.writePending(_pending());
      await store.completeAndEnqueue(_completed());
      await store.append(_completed());
      expect(await store.snapshot(), hasLength(1));
    });
  });

  test('coordinator commits outcome and outbox through one shared store', () async {
    final store = InMemoryTransactionalPluginRevocationStore();
    final coordinator = PluginRevocationCoordinator(
      manager: PluginManager(),
      executionStore: store,
      auditSink: store,
      approve: (_) => true,
    );

    final report = await coordinator.execute(
      operationId: 'coordinated-op',
      decisions: [
        CapabilityImpactDecision(
          pluginId: 'plugin',
          providerOwnerId: 'provider',
          providerState: CapabilityProviderHealthState.unavailable,
          action: CapabilityImpactAction.notify,
          reason: 'provider unavailable',
        ),
      ],
    );

    expect(report.records.single.status, PluginRevocationExecutionStatus.noOp);
    final persisted = await store.read(report.records.single.idempotencyKey);
    expect(persisted!.status, PluginRevocationExecutionStatus.noOp);
    final messages = await store.snapshot();
    expect(messages, hasLength(1));
    expect(messages.single.event.outcome, PluginRevocationExecutionStatus.noOp.name);
  });

  group('PluginRevocationOutboxDispatcher', () {
    test('delivers leased events and marks them delivered', () async {
      final store = InMemoryTransactionalPluginRevocationStore();
      await store.writePending(_pending());
      await store.completeAndEnqueue(_completed());
      final publisher = _Publisher();
      final dispatcher = PluginRevocationOutboxDispatcher(
        store: store,
        publisher: publisher,
        workerId: 'worker-a',
        clock: () => DateTime.utc(2026, 1, 2),
      );

      final report = await dispatcher.dispatchBatch();
      expect(report.claimed, 1);
      expect(report.delivered, 1);
      expect(publisher.events, hasLength(1));
      expect((await store.snapshot()).single.state,
          PluginRevocationOutboxState.delivered);
    });

    test('reschedules failures then dead-letters after max attempts', () async {
      final store = InMemoryTransactionalPluginRevocationStore();
      await store.writePending(_pending());
      await store.completeAndEnqueue(_completed());
      final publisher = _Publisher()..fail = true;
      var now = DateTime.utc(2026, 1, 2);
      final dispatcher = PluginRevocationOutboxDispatcher(
        store: store,
        publisher: publisher,
        workerId: 'worker-a',
        maxAttempts: 2,
        backoff: (_) => Duration.zero,
        clock: () => now,
      );

      final first = await dispatcher.dispatchBatch();
      expect(first.rescheduled, 1);
      now = now.add(const Duration(seconds: 1));
      final second = await dispatcher.dispatchBatch();
      expect(second.deadLettered, 1);
      expect((await store.snapshot()).single.state,
          PluginRevocationOutboxState.deadLetter);
    });

    test('stale lease token cannot acknowledge a reclaimed event', () async {
      final store = InMemoryTransactionalPluginRevocationStore();
      await store.writePending(_pending());
      await store.completeAndEnqueue(_completed());
      final first = (await store.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 2),
        leaseDuration: const Duration(seconds: 1),
        limit: 1,
      )).single;
      final second = (await store.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 2, 0, 0, 2),
        leaseDuration: const Duration(seconds: 10),
        limit: 1,
      )).single;

      expect(await store.markDelivered(
        eventId: first.event.eventId,
        leaseToken: first.leaseToken!,
        deliveredAt: DateTime.utc(2026, 1, 2, 0, 0, 3),
      ), isFalse);
      expect(await store.markDelivered(
        eventId: second.event.eventId,
        leaseToken: second.leaseToken!,
        deliveredAt: DateTime.utc(2026, 1, 2, 0, 0, 3),
      ), isTrue);
    });
  });
}

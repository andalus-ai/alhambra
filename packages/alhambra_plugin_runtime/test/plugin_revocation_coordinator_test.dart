import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

CapabilityImpactDecision decision(
  CapabilityImpactAction action, {
  String pluginId = 'consumer',
}) =>
    CapabilityImpactDecision(
      pluginId: pluginId,
      providerOwnerId: 'storage',
      providerState: action == CapabilityImpactAction.recovered
          ? CapabilityProviderHealthState.healthy
          : CapabilityProviderHealthState.unavailable,
      action: action,
      reason: 'test transition',
    );

void main() {
  group('PluginRevocationCoordinator', () {
    test('requires host approval before applying a decision', () async {
      final store = InMemoryPluginRevocationExecutionStore();
      final audit = InMemoryPluginRevocationAuditSink();
      var approvalCalls = 0;
      final coordinator = PluginRevocationCoordinator(
        manager: PluginManager(),
        executionStore: store,
        auditSink: audit,
        approve: (_) {
          approvalCalls++;
          return false;
        },
      );

      final report = await coordinator.execute(
        operationId: 'provider-event-1',
        decisions: [decision(CapabilityImpactAction.deactivate)],
      );

      expect(approvalCalls, 1);
      expect(report.records.single.status,
          PluginRevocationExecutionStatus.rejected);
      expect(audit.records, hasLength(1));
      expect(report.succeeded, isFalse);
    });

    test('records notify as a host-delegated no-op and is idempotent', () async {
      final store = InMemoryPluginRevocationExecutionStore();
      final audit = InMemoryPluginRevocationAuditSink();
      final coordinator = PluginRevocationCoordinator(
        manager: PluginManager(),
        executionStore: store,
        auditSink: audit,
        approve: (_) => true,
      );

      final first = await coordinator.execute(
        operationId: 'provider-event-2',
        decisions: [decision(CapabilityImpactAction.notify)],
      );
      final second = await coordinator.execute(
        operationId: 'provider-event-2',
        decisions: [decision(CapabilityImpactAction.notify)],
      );

      expect(first.records.single.status, PluginRevocationExecutionStatus.noOp);
      expect(second.records.single.status,
          PluginRevocationExecutionStatus.alreadyCompleted);
      expect(audit.records, hasLength(1));
    });

    test('does not claim suspend support before lifecycle contract exists',
        () async {
      final coordinator = PluginRevocationCoordinator(
        manager: PluginManager(),
        executionStore: InMemoryPluginRevocationExecutionStore(),
        auditSink: InMemoryPluginRevocationAuditSink(),
        approve: (_) => true,
      );

      final report = await coordinator.execute(
        operationId: 'provider-event-3',
        decisions: [decision(CapabilityImpactAction.suspend)],
      );

      expect(report.records.single.status,
          PluginRevocationExecutionStatus.unsupported);
      expect(report.succeeded, isFalse);
    });

    test('moves active plugin health to degraded and recovers it', () async {
      final health = PluginRuntimeHealthRegistry()
        ..observe(
          pluginId: 'consumer',
          state: PluginRuntimeState.active,
        );
      final coordinator = PluginRevocationCoordinator(
        manager: PluginManager(),
        healthRegistry: health,
        executionStore: InMemoryPluginRevocationExecutionStore(),
        auditSink: InMemoryPluginRevocationAuditSink(),
        approve: (_) => true,
      );

      final degraded = await coordinator.execute(
        operationId: 'provider-event-4',
        decisions: [decision(CapabilityImpactAction.markDegraded)],
      );
      expect(degraded.records.single.status,
          PluginRevocationExecutionStatus.completed);
      expect(health.snapshotOf('consumer')!.state,
          PluginRuntimeState.degraded);

      final recovered = await coordinator.execute(
        operationId: 'provider-event-5',
        decisions: [decision(CapabilityImpactAction.recovered)],
      );
      expect(recovered.records.single.status,
          PluginRevocationExecutionStatus.completed);
      expect(health.snapshotOf('consumer')!.state,
          PluginRuntimeState.active);
    });

    test('leaves a pending record for reconciliation after interruption',
        () async {
      final store = _InterruptedStore();
      final coordinator = PluginRevocationCoordinator(
        manager: PluginManager(),
        executionStore: store,
        auditSink: InMemoryPluginRevocationAuditSink(),
        approve: (_) => throw StateError('approval service unavailable'),
      );

      final first = await coordinator.execute(
        operationId: 'provider-event-6',
        decisions: [decision(CapabilityImpactAction.deactivate)],
      );
      final retry = await coordinator.execute(
        operationId: 'provider-event-6',
        decisions: [decision(CapabilityImpactAction.deactivate)],
      );

      expect(first.records.single.status,
          PluginRevocationExecutionStatus.failed);
      expect(retry.records.single.status,
          PluginRevocationExecutionStatus.requiresReconciliation);
    });
  });
}

class _InterruptedStore implements PluginRevocationExecutionStore {
  final Map<String, PluginRevocationExecutionRecord> records = {};

  @override
  Future<PluginRevocationExecutionRecord?> read(String key) async =>
      records[key];

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) async {
    if (records.containsKey(record.idempotencyKey)) return false;
    records[record.idempotencyKey] = record;
    return true;
  }

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) async {
    if (record.status == PluginRevocationExecutionStatus.failed) {
      throw StateError('simulated durable-store interruption');
    }
    records[record.idempotencyKey] = record;
  }
}

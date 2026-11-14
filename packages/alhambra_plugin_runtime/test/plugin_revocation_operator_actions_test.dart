import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginRevocationExecutionRecord _record({
  required PluginRevocationExecutionStatus status,
  required DateTime at,
}) => PluginRevocationExecutionRecord(
  idempotencyKey: 'op:plugin:provider:deactivate',
  operationId: 'op',
  pluginId: 'plugin',
  providerOwnerId: 'provider',
  action: CapabilityImpactAction.deactivate,
  status: status,
  updatedAt: at,
);

void main() {
  test('dead-letter replay creates a new event and atomically records operator audit', () async {
    final store = InMemoryTransactionalPluginRevocationStore();
    await store.writePending(_record(
      status: PluginRevocationExecutionStatus.requiresReconciliation,
      at: DateTime.utc(2026, 1, 1),
    ));
    await store.completeAndEnqueue(_record(
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));

    final original = (await store.claim(
      workerId: 'worker',
      now: DateTime.utc(2026, 1, 2),
      leaseDuration: const Duration(seconds: 10),
      limit: 1,
      maxAttempts: 1,
    )).single;
    expect(await store.reschedule(
      eventId: original.event.eventId,
      leaseToken: original.leaseToken!,
      nextAttemptAt: DateTime.utc(2026, 1, 2),
      errorCode: 'publisher_unavailable',
      maxAttempts: 1,
    ), isTrue);

    final request = PluginRevocationReplayRequest(
      actionId: 'approval-001',
      actorId: 'operator-7',
      reason: 'Downstream audit sink restored; replay approved.',
      approvalReference: 'change-ticket-42',
      targetEventId: original.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 3),
    );
    final result = await store.replayDeadLetter(request);

    expect(result, isNotNull);
    expect(result!.audit.actorId, 'operator-7');
    expect(result.audit.approvalReference, 'change-ticket-42');
    expect(result.audit.replayGeneration, 1);
    expect(result.replay.event.eventId, isNot(original.event.eventId));
    expect(result.replay.event.idempotencyKey, isNot(original.event.idempotencyKey));
    expect(result.replay.event.replayOfEventId, original.event.eventId);
    expect(result.replay.event.replayGeneration, 1);
    expect(result.replay.state, PluginRevocationOutboxState.pending);
    expect(result.replay.attempts, 0);

    final all = await store.readAllOutbox();
    expect(all, hasLength(2));
    expect(all.singleWhere((item) => item.event.eventId == original.event.eventId).state,
        PluginRevocationOutboxState.deadLetter);
    expect(await store.readOperatorActions(), hasLength(1));
  });

  test('operator action ID is idempotent and cannot be reused for another command', () async {
    final store = InMemoryTransactionalPluginRevocationStore();
    await store.writePending(_record(
      status: PluginRevocationExecutionStatus.requiresReconciliation,
      at: DateTime.utc(2026, 1, 1),
    ));
    await store.completeAndEnqueue(_record(
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));
    final original = (await store.claim(
      workerId: 'worker',
      now: DateTime.utc(2026, 1, 2),
      leaseDuration: const Duration(seconds: 10),
      limit: 1,
      maxAttempts: 1,
    )).single;
    await store.reschedule(
      eventId: original.event.eventId,
      leaseToken: original.leaseToken!,
      nextAttemptAt: DateTime.utc(2026, 1, 2),
      errorCode: 'failed',
      maxAttempts: 1,
    );
    PluginRevocationReplayRequest request() => PluginRevocationReplayRequest(
      actionId: 'same-action',
      actorId: 'operator',
      reason: 'approved replay',
      approvalReference: 'ticket-1',
      targetEventId: original.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 3),
    );

    final first = await store.replayDeadLetter(request());
    final second = await store.replayDeadLetter(request());
    expect(second!.replay.event.eventId, first!.replay.event.eventId);
    expect(await store.readOperatorActions(), hasLength(1));

    await expectLater(store.replayDeadLetter(PluginRevocationReplayRequest(
      actionId: 'same-action',
      actorId: 'different-operator',
      reason: 'different reason',
      approvalReference: 'ticket-2',
      targetEventId: original.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 4),
    )), throwsStateError);
  });

  test('cannot replay an event that is not dead-lettered', () async {
    final store = InMemoryTransactionalPluginRevocationStore();
    await store.writePending(_record(
      status: PluginRevocationExecutionStatus.requiresReconciliation,
      at: DateTime.utc(2026, 1, 1),
    ));
    await store.completeAndEnqueue(_record(
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));
    final message = (await store.readAllOutbox()).single;
    final result = await store.replayDeadLetter(PluginRevocationReplayRequest(
      actionId: 'action',
      actorId: 'operator',
      reason: 'not dead letter',
      approvalReference: 'ticket',
      targetEventId: message.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 2),
    ));
    expect(result, isNull);
    expect(await store.readOperatorActions(), isEmpty);
  });
}

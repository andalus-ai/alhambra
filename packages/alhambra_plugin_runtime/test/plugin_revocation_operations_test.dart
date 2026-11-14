import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginRevocationExecutionRecord _record(
  String key, {
  PluginRevocationExecutionStatus status =
      PluginRevocationExecutionStatus.requiresReconciliation,
  DateTime? at,
}) =>
    PluginRevocationExecutionRecord(
      idempotencyKey: key,
      operationId: 'operation-$key',
      pluginId: 'plugin-$key',
      providerOwnerId: 'provider',
      action: CapabilityImpactAction.deactivate,
      status: status,
      updatedAt: at ?? DateTime.utc(2026, 1, 1),
      detail: 'sanitized',
    );

PluginRevocationJournalEntry _journal(
  String key, {
  PluginRevocationJournalStatus status = PluginRevocationJournalStatus.pending,
  int revision = 1,
}) {
  final created = DateTime.utc(2026, 1, 1);
  return PluginRevocationJournalEntry(
    idempotencyKey: key,
    operationId: 'operation-$key',
    pluginId: 'plugin-$key',
    providerOwnerId: 'provider',
    action: CapabilityImpactAction.deactivate,
    status: status,
    revision: revision,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  test('operations snapshot counts journal and outbox states without claiming', () async {
    final journal = InMemoryPluginRevocationJournalStore();
    final outbox = InMemoryTransactionalPluginRevocationStore();
    final capturedAt = DateTime.utc(2026, 1, 3);

    await journal.insertIfAbsent(_journal('journal-pending'));
    await journal.insertIfAbsent(_journal(
      'journal-completed',
      status: PluginRevocationJournalStatus.completed,
    ));
    await journal.insertIfAbsent(_journal(
      'journal-manual',
      status: PluginRevocationJournalStatus.manualReview,
      revision: 2,
    ));

    final leased = _record('event-leased');
    await outbox.writePending(leased);
    await outbox.completeAndEnqueue(_record(
      'event-leased',
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 0),
    ));
    final lease = (await outbox.claim(
      workerId: 'worker-a',
      now: DateTime.utc(2026, 1, 2),
      leaseDuration: const Duration(seconds: 1),
      limit: 1,
      maxAttempts: 3,
    )).single;

    final dead = _record('event-dead');
    await outbox.writePending(dead);
    await outbox.completeAndEnqueue(_record(
      'event-dead',
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));
    final deadLease = (await outbox.claim(
      workerId: 'worker-b',
      now: DateTime.utc(2026, 1, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 1,
      maxAttempts: 1,
    )).single;
    await outbox.reschedule(
      eventId: deadLease.event.eventId,
      leaseToken: deadLease.leaseToken!,
      nextAttemptAt: capturedAt,
      errorCode: 'publisher_unavailable',
      maxAttempts: 1,
    );

    final pending = _record('event-pending');
    await outbox.writePending(pending);
    await outbox.completeAndEnqueue(_record(
      'event-pending',
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 2),
    ));

    final before = await outbox.readAllOutbox();
    final service = PluginRevocationOperationsService(
      journalStore: journal,
      outboxStore: outbox,
      clock: () => capturedAt,
    );
    final snapshot = await service.inspect();
    final after = await outbox.readAllOutbox();

    expect(snapshot.capturedAt, capturedAt);
    expect(snapshot.totalJournalEntries, 3);
    expect(snapshot.journalCounts[PluginRevocationJournalStatus.pending], 1);
    expect(snapshot.journalCounts[PluginRevocationJournalStatus.completed], 1);
    expect(snapshot.journalCounts[PluginRevocationJournalStatus.manualReview], 1);
    expect(snapshot.unresolvedJournalEntries, 2);
    expect(snapshot.totalOutboxMessages, 3);
    expect(snapshot.pendingOutboxMessages, 1);
    expect(snapshot.leasedOutboxMessages, 1);
    expect(snapshot.deadLetterOutboxMessages, 1);
    expect(snapshot.overduePendingMessages, 1);
    expect(snapshot.expiredLeases, 1);
    expect(lease.state, PluginRevocationOutboxState.leased);
    expect(after.map((m) => m.state).toList(), before.map((m) => m.state).toList());
  });

  test('snapshot collections and counters are immutable', () async {
    final journal = InMemoryPluginRevocationJournalStore();
    final outbox = InMemoryTransactionalPluginRevocationStore();
    final snapshot = await PluginRevocationOperationsService(
      journalStore: journal,
      outboxStore: outbox,
      clock: () => DateTime.utc(2026, 1, 1),
    ).inspect();

    expect(() => snapshot.journalCounts.clear(), throwsUnsupportedError);
    expect(() => snapshot.outboxCounts.clear(), throwsUnsupportedError);
    expect(() => snapshot.journalEntries.add(_journal('mutate')),
        throwsUnsupportedError);
    expect(() => snapshot.outboxMessages.clear(), throwsUnsupportedError);
  });
}

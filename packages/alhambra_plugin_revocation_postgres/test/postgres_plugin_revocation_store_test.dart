import 'dart:io';

import 'package:alhambra_plugin_revocation_postgres/alhambra_plugin_revocation_postgres.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

final databaseUrl = Platform.environment['ALHAMBRA_TEST_DATABASE_URL'];

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

void main() {
  final skipReason = databaseUrl == null
      ? 'Set ALHAMBRA_TEST_DATABASE_URL to run PostgreSQL integration tests.'
      : false;

  test('transactionally commits execution, journal and outbox', () async {
    final store = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    await store.migrate();
    final key = 'atomic-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(store.close);

    final pending = _record(key);
    expect(await store.writePending(pending), isTrue);
    expect(await store.writePending(pending), isFalse);
    final initialJournal = await store.journalStore.read(key);
    expect(initialJournal?.status, PluginRevocationJournalStatus.pending);
    expect(initialJournal?.revision, 1);

    final terminal = _record(
      key,
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    );
    await store.completeAndEnqueue(terminal);

    expect((await store.read(key))?.status,
        PluginRevocationExecutionStatus.completed);
    expect((await store.journalStore.read(key))?.status,
        PluginRevocationJournalStatus.completed);

    final inspected = await store.readAllOutbox();
    expect(inspected.where((item) => item.event.idempotencyKey == key), hasLength(1));
    final inspectedMessage =
        inspected.singleWhere((item) => item.event.idempotencyKey == key);
    expect(inspectedMessage.state, PluginRevocationOutboxState.pending);
    expect(inspectedMessage.attempts, 0);

    final claimed = await store.claim(
      workerId: 'integration-worker',
      now: DateTime.utc(2026, 1, 1, 0, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 10,
      maxAttempts: 3,
    );
    final message = claimed.singleWhere((item) => item.event.idempotencyKey == key);
    expect(message.event.outcome, 'completed');
    expect(message.attempts, 1);
    expect(
      await store.markDelivered(
        eventId: message.event.eventId,
        leaseToken: message.leaseToken!,
        deliveredAt: DateTime.utc(2026, 1, 1, 0, 3),
      ),
      isTrue,
    );
  }, skip: skipReason);

  test('concurrent independent pools cannot claim the same event', () async {
    final first = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    final second = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    await first.migrate();
    final key = 'race-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(() async {
      await first.close();
      await second.close();
    });

    await first.writePending(_record(key));
    await first.completeAndEnqueue(_record(
      key,
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));

    final claims = await Future.wait([
      first.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 10,
        maxAttempts: 3,
      ),
      second.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 10,
        maxAttempts: 3,
      ),
    ]);
    final matching = claims.expand((batch) => batch)
        .where((item) => item.event.idempotencyKey == key);
    expect(matching, hasLength(1));
  }, skip: skipReason);

  test('expired leases are reclaimed, fenced and dead-lettered at limit', () async {
    final store = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    await store.migrate();
    final key = 'lease-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(store.close);

    await store.writePending(_record(key));
    await store.completeAndEnqueue(_record(
      key,
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));

    final first = (await store.claim(
      workerId: 'worker-a',
      now: DateTime.utc(2026, 1, 1, 0, 2),
      leaseDuration: const Duration(seconds: 1),
      limit: 1,
      maxAttempts: 2,
    )).single;
    final second = (await store.claim(
      workerId: 'worker-b',
      now: DateTime.utc(2026, 1, 1, 0, 2, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 1,
      maxAttempts: 2,
    )).single;

    expect(second.attempts, 2);
    expect(second.leaseToken, isNot(first.leaseToken));
    expect(
      await store.markDelivered(
        eventId: first.event.eventId,
        leaseToken: first.leaseToken!,
        deliveredAt: DateTime.utc(2026, 1, 1, 0, 2, 3),
      ),
      isFalse,
    );
    expect(
      await store.reschedule(
        eventId: second.event.eventId,
        leaseToken: second.leaseToken!,
        nextAttemptAt: DateTime.utc(2026, 1, 1, 0, 3),
        errorCode: 'publisher_unavailable',
        maxAttempts: 2,
      ),
      isTrue,
    );

    final exhausted = await store.claim(
      workerId: 'worker-c',
      now: DateTime.utc(2026, 1, 1, 0, 4),
      leaseDuration: const Duration(seconds: 30),
      limit: 10,
      maxAttempts: 2,
    );
    expect(exhausted, isEmpty);
  }, skip: skipReason);

  test('journal compare-and-set rejects stale revisions', () async {
    final store = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    await store.migrate();
    final key = 'cas-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(store.close);

    await store.writePending(_record(key));
    final journal = store.journalStore;
    final current = (await journal.read(key))!;
    final replacement = current.next(
      status: PluginRevocationJournalStatus.completed,
      at: current.updatedAt.add(const Duration(seconds: 1)),
    );

    expect(
      await journal.compareAndSet(
        idempotencyKey: key,
        expectedRevision: current.revision,
        replacement: replacement,
      ),
      isTrue,
    );
    expect(
      await journal.compareAndSet(
        idempotencyKey: key,
        expectedRevision: current.revision,
        replacement: replacement,
      ),
      isFalse,
    );
  }, skip: skipReason);

  test('completion rolls back if journal update cannot be applied', () async {
    final store = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    final admin = Pool.withUrl(databaseUrl!);
    await store.migrate();
    final key = 'rollback-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(() async {
      await store.close();
      await admin.close();
    });

    await store.writePending(_record(key));
    await admin.execute(
      r'DELETE FROM alhambra_plugin_revocation_journal WHERE idempotency_key = $1',
      parameters: [key],
    );

    await expectLater(
      store.completeAndEnqueue(_record(
        key,
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      )),
      throwsStateError,
    );

    expect((await store.read(key))?.status,
        PluginRevocationExecutionStatus.requiresReconciliation);
    final claimed = await store.claim(
      workerId: 'rollback-check',
      now: DateTime.utc(2026, 1, 1, 0, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 100,
      maxAttempts: 3,
    );
    expect(claimed.any((item) => item.event.idempotencyKey == key), isFalse);
  }, skip: skipReason);

  test('audited replay is durable, idempotent and allocates generations', () async {
    final store = PostgresPluginRevocationStore.fromUrl(databaseUrl!);
    await store.migrate();
    final key = 'replay-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(store.close);
    await store.writePending(_record(key));
    await store.completeAndEnqueue(_record(
      key,
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));
    final claimed = (await store.claim(
      workerId: 'replay-worker',
      now: DateTime.utc(2026, 1, 1, 0, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 100,
      maxAttempts: 1,
    )).singleWhere((item) => item.event.idempotencyKey == key);
    await store.reschedule(
      eventId: claimed.event.eventId,
      leaseToken: claimed.leaseToken!,
      nextAttemptAt: DateTime.utc(2026, 1, 1, 0, 3),
      errorCode: 'publisher_unavailable',
      maxAttempts: 1,
    );
    final request = PluginRevocationReplayRequest(
      actionId: 'pg-action-$key',
      actorId: 'operator-1',
      scopeId: 'tenant-blue',
      reason: 'Approved after sink recovery',
      approvalReference: 'change-$key',
      targetEventId: claimed.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 1, 0, 4),
    );
    final results = await Future.wait([
      store.replayDeadLetter(request),
      store.replayDeadLetter(request),
    ]);
    final first = results.first!;
    expect(results.last!.replay.event.eventId, first.replay.event.eventId);
    expect(first.audit.replayGeneration, 1);
    expect(first.audit.scopeId, 'tenant-blue');
    expect(first.replay.event.replayOfEventId, claimed.event.eventId);
    expect(first.replay.event.replayGeneration, 1);
    expect(first.replay.state, PluginRevocationOutboxState.pending);
    expect(first.replay.attempts, 0);
    expect(await store.readOperatorActions(), hasLength(1));
    final all = await store.readAllOutbox();
    expect(all.singleWhere((m) => m.event.eventId == claimed.event.eventId).state,
        PluginRevocationOutboxState.deadLetter);

    final second = await store.replayDeadLetter(PluginRevocationReplayRequest(
      actionId: 'pg-action-2-$key',
      actorId: 'operator-2',
      scopeId: 'tenant-blue',
      reason: 'Second approved replay generation',
      approvalReference: 'change-2-$key',
      targetEventId: claimed.event.eventId,
      occurredAt: DateTime.utc(2026, 1, 1, 0, 5),
    ));
    expect(second!.audit.replayGeneration, 2);
    expect(second.replay.event.eventId, isNot(first.replay.event.eventId));
    expect(await store.readOperatorActions(), hasLength(2));
  }, skip: skipReason);

}

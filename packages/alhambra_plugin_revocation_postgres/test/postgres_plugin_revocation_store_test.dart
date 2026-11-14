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
}

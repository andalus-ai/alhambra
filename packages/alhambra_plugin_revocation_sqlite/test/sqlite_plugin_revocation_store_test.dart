import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_revocation_sqlite/alhambra_plugin_revocation_sqlite.dart';
import 'package:test/test.dart';

PluginRevocationExecutionRecord _record({
  PluginRevocationExecutionStatus status =
      PluginRevocationExecutionStatus.requiresReconciliation,
  DateTime? at,
}) =>
    PluginRevocationExecutionRecord(
      idempotencyKey: 'operation:plugin:provider:deactivate',
      operationId: 'operation',
      pluginId: 'plugin',
      providerOwnerId: 'provider',
      action: CapabilityImpactAction.deactivate,
      status: status,
      updatedAt: at ?? DateTime.utc(2026, 1, 1),
      detail: 'sanitized',
    );

void main() {
  group('SqlitePluginRevocationStore', () {
    late SqlitePluginRevocationStore store;

    setUp(() {
      store = SqlitePluginRevocationStore.memory();
    });

    tearDown(() => store.close());

    test('commits terminal execution and outbox event atomically', () async {
      final pending = _record();
      expect(await store.writePending(pending), isTrue);
      expect(await store.writePending(pending), isFalse);
      final initialJournal =
          await store.journalStore.read(pending.idempotencyKey);
      expect(initialJournal?.status, PluginRevocationJournalStatus.pending);
      expect(initialJournal?.revision, 1);

      final terminal = _record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await store.completeAndEnqueue(terminal);

      final execution = await store.read(pending.idempotencyKey);
      expect(execution?.status, PluginRevocationExecutionStatus.completed);

      final journal = await store.journalStore.read(pending.idempotencyKey);
      expect(journal?.status, PluginRevocationJournalStatus.completed);
      expect(journal?.revision, 2);
      expect(journal?.detail, terminal.detail);

      final inspected = await store.readAllOutbox();
      expect(inspected, hasLength(1));
      expect(inspected.single.state, PluginRevocationOutboxState.pending);
      expect(inspected.single.attempts, 0);

      final claimed = await store.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 10,
        maxAttempts: 3,
      );
      expect(claimed, hasLength(1));
      expect(claimed.single.event.eventId, '${pending.idempotencyKey}:terminal');
      expect(claimed.single.event.outcome, 'completed');
      expect(claimed.single.attempts, 1);
    });

    test('expired lease is reclaimed and stale worker is fenced', () async {
      final pending = _record();
      await store.writePending(pending);
      await store.completeAndEnqueue(_record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final first = (await store.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 1),
        limit: 1,
        maxAttempts: 3,
      )).single;
      final second = (await store.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 1, 0, 2, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 3,
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
          eventId: first.event.eventId,
          leaseToken: first.leaseToken!,
          nextAttemptAt: DateTime.utc(2026, 1, 1, 0, 3),
          errorCode: 'stale_worker',
          maxAttempts: 3,
        ),
        isFalse,
      );
    });

    test('final failed delivery is dead-lettered', () async {
      final pending = _record();
      await store.writePending(pending);
      await store.completeAndEnqueue(_record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final message = (await store.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 1,
      )).single;

      expect(
        await store.reschedule(
          eventId: message.event.eventId,
          leaseToken: message.leaseToken!,
          nextAttemptAt: DateTime.utc(2026, 1, 1, 0, 3),
          errorCode: 'publisher_unavailable',
          maxAttempts: 1,
        ),
        isTrue,
      );
      final nextClaim = await store.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 1, 0, 4),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 1,
      );
      expect(nextClaim, isEmpty);
    });

    test('lease token fences stale acknowledgements', () async {
      await store.writePending(_record());
      await store.completeAndEnqueue(_record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final first = (await store.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 1),
        limit: 1,
        maxAttempts: 3,
      )).single;
      final second = (await store.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 1, 0, 2, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 3,
      )).single;

      expect(
        await store.markDelivered(
          eventId: first.event.eventId,
          leaseToken: first.leaseToken!,
          deliveredAt: DateTime.utc(2026, 1, 1, 0, 2, 3),
        ),
        isFalse,
      );
      expect(
        await store.markDelivered(
          eventId: second.event.eventId,
          leaseToken: second.leaseToken!,
          deliveredAt: DateTime.utc(2026, 1, 1, 0, 2, 4),
        ),
        isTrue,
      );
    });

    test('journal adapter performs revision compare-and-set', () async {
      final journal = store.journalStore;
      final entry = PluginRevocationJournalEntry(
        idempotencyKey: 'journal-key',
        operationId: 'op',
        pluginId: 'plugin',
        providerOwnerId: 'provider',
        action: CapabilityImpactAction.deactivate,
        status: PluginRevocationJournalStatus.pending,
        revision: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(await journal.insertIfAbsent(entry), isTrue);
      expect(await journal.insertIfAbsent(entry), isFalse);

      final replacement = entry.next(
        status: PluginRevocationJournalStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      );
      expect(
        await journal.compareAndSet(
          idempotencyKey: entry.idempotencyKey,
          expectedRevision: 1,
          replacement: replacement,
        ),
        isTrue,
      );
      expect(
        await journal.compareAndSet(
          idempotencyKey: entry.idempotencyKey,
          expectedRevision: 1,
          replacement: replacement,
        ),
        isFalse,
      );
      expect((await journal.read(entry.idempotencyKey))?.revision, 2);
    });
  });

  test('completion rolls back when its journal row is missing', () async {
    final directory = await Directory.systemTemp.createTemp('alhambra-revocation-rollback-');
    final databasePath = '${directory.path}/revocations.sqlite';
    final store = SqlitePluginRevocationStore(databasePath);
    final admin = sq.sqlite3.open(databasePath);
    addTearDown(() async {
      admin.dispose();
      store.close();
      await directory.delete(recursive: true);
    });

    final pending = _record();
    await store.writePending(pending);
    admin.execute(
      'DELETE FROM plugin_revocation_journal WHERE idempotency_key = ?',
      [pending.idempotencyKey],
    );

    await expectLater(
      store.completeAndEnqueue(_record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      )),
      throwsStateError,
    );

    expect(
      (await store.read(pending.idempotencyKey))?.status,
      PluginRevocationExecutionStatus.requiresReconciliation,
    );
    final claimed = await store.claim(
      workerId: 'rollback-check',
      now: DateTime.utc(2026, 1, 1, 0, 2),
      leaseDuration: const Duration(seconds: 30),
      limit: 10,
      maxAttempts: 3,
    );
    expect(claimed, isEmpty);
  });

  test('independent connections serialize claims for a file database', () async {
    final directory = await Directory.systemTemp.createTemp('alhambra-revocation-');
    final databasePath = '${directory.path}/revocations.sqlite';
    final first = SqlitePluginRevocationStore(databasePath);
    final second = SqlitePluginRevocationStore(databasePath);
    addTearDown(() async {
      first.close();
      second.close();
      await directory.delete(recursive: true);
    });

    final pending = _record();
    await first.writePending(pending);
    await first.completeAndEnqueue(_record(
      status: PluginRevocationExecutionStatus.completed,
      at: DateTime.utc(2026, 1, 1, 0, 1),
    ));

    final claims = await Future.wait([
      first.claim(
        workerId: 'worker-a',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 3,
      ),
      second.claim(
        workerId: 'worker-b',
        now: DateTime.utc(2026, 1, 1, 0, 2),
        leaseDuration: const Duration(seconds: 30),
        limit: 1,
        maxAttempts: 3,
      ),
    ]);
    expect(claims.fold<int>(0, (sum, batch) => sum + batch.length), 1);
  });
}

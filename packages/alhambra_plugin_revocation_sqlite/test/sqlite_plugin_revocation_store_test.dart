import 'dart:io';

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

      final terminal = _record(
        status: PluginRevocationExecutionStatus.completed,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await store.completeAndEnqueue(terminal);

      final execution = await store.read(pending.idempotencyKey);
      expect(execution?.status, PluginRevocationExecutionStatus.completed);

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

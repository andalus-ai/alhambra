import 'dart:io';

import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqlitePluginInstallOperationLeaseStore', () {
    test('persists monotonic fencing tokens across reopen and release', () async {
      final directory = await Directory.systemTemp.createTemp('alhambra-install-lease-');
      final path = '${directory.path}/leases.sqlite';
      final first = SqlitePluginInstallOperationLeaseStore(path);
      final now = DateTime.utc(2026, 1, 1);
      final lease1 = (await first.acquire(
        operationId: 'operation-1',
        ownerId: 'worker-a',
        now: now,
        leaseDuration: const Duration(seconds: 30),
      ))!;
      expect(lease1.fencingToken, 1);
      expect(await first.release(lease: lease1, now: now.add(const Duration(seconds: 1))), isTrue);
      first.close();

      final reopened = SqlitePluginInstallOperationLeaseStore(path);
      addTearDown(() async {
        reopened.close();
        await directory.delete(recursive: true);
      });
      final lease2 = await reopened.acquire(
        operationId: 'operation-1',
        ownerId: 'worker-b',
        now: now.add(const Duration(seconds: 2)),
        leaseDuration: const Duration(seconds: 30),
      );
      expect(lease2!.fencingToken, 2);
      expect(await reopened.isCurrent(lease: lease1, now: now.add(const Duration(seconds: 2))), isFalse);
      expect(await reopened.isCurrent(lease: lease2, now: now.add(const Duration(seconds: 2))), isTrue);
    });

    test('serializes competing connections and only grants one active owner', () async {
      final directory = await Directory.systemTemp.createTemp('alhambra-install-lease-race-');
      final path = '${directory.path}/leases.sqlite';
      final first = SqlitePluginInstallOperationLeaseStore(path);
      final second = SqlitePluginInstallOperationLeaseStore(path);
      addTearDown(() async {
        first.close();
        second.close();
        await directory.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 1, 1);
      final results = await Future.wait([
        first.acquire(
          operationId: 'operation-race',
          ownerId: 'worker-a',
          now: now,
          leaseDuration: const Duration(minutes: 1),
        ),
        second.acquire(
          operationId: 'operation-race',
          ownerId: 'worker-b',
          now: now,
          leaseDuration: const Duration(minutes: 1),
        ),
      ]);
      expect(results.whereType<Object>(), hasLength(1));
      expect(results.where((lease) => lease == null), hasLength(1));
    });

    test('same owner reacquisition is idempotent and renew rejects stale lease', () async {
      final store = SqlitePluginInstallOperationLeaseStore.memory();
      addTearDown(store.close);
      final now = DateTime.utc(2026, 1, 1);
      final lease = (await store.acquire(
        operationId: 'operation-1',
        ownerId: 'worker-a',
        now: now,
        leaseDuration: const Duration(seconds: 10),
      ))!;
      final same = await store.acquire(
        operationId: 'operation-1',
        ownerId: 'worker-a',
        now: now.add(const Duration(seconds: 1)),
        leaseDuration: const Duration(seconds: 10),
      );
      expect(same!.fencingToken, lease.fencingToken);
      final renewed = await store.renew(
        lease: lease,
        now: now.add(const Duration(seconds: 2)),
        leaseDuration: const Duration(seconds: 20),
      );
      expect(renewed!.expiresAt, now.add(const Duration(seconds: 22)));
      expect(await store.renew(
        lease: lease,
        now: now.add(const Duration(seconds: 3)),
        leaseDuration: const Duration(seconds: 20),
      ), isNull);
    });
  });
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryPluginInstallOperationLeaseStore', () {
    const duration = Duration(seconds: 30);
    final start = DateTime.utc(2026, 1, 1);

    test('only one owner acquires an unexpired operation lease', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      );
      final competing = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-b',
        now: start.add(const Duration(seconds: 1)),
        leaseDuration: duration,
      );
      expect(first, isNotNull);
      expect(competing, isNull);
    });

    test('same owner reacquisition is idempotent and does not mint a token',
        () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      );
      final repeated = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start.add(const Duration(seconds: 1)),
        leaseDuration: duration,
      );
      expect(repeated!.fencingToken, first!.fencingToken);
      expect(repeated.expiresAt, first.expiresAt);
    });

    test('expiry grants a strictly larger fencing token', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      );
      final second = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-b',
        now: first!.expiresAt,
        leaseDuration: duration,
      );
      expect(second, isNotNull);
      expect(second!.fencingToken, greaterThan(first.fencingToken));
      expect(await store.isCurrent(lease: first, now: first.expiresAt), isFalse);
      expect(await store.isCurrent(lease: second, now: start), isFalse);
    });

    test('renewal preserves token and extends expiry', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = (await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      ))!;
      final renewed = await store.renew(
        lease: first,
        now: start.add(const Duration(seconds: 10)),
        leaseDuration: duration,
      );
      expect(renewed, isNotNull);
      expect(renewed!.fencingToken, first.fencingToken);
      expect(renewed.expiresAt, start.add(const Duration(seconds: 40)));
      expect(await store.isCurrent(lease: first, now: start), isTrue);
    });

    test('expired or superseded lease cannot renew or release new owner', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = (await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      ))!;
      final second = (await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-b',
        now: first.expiresAt,
        leaseDuration: duration,
      ))!;
      expect(await store.renew(
        lease: first,
        now: first.expiresAt,
        leaseDuration: duration,
      ), isNull);
      expect(await store.release(lease: first, now: first.expiresAt), isFalse);
      expect(await store.isCurrent(lease: second, now: first.expiresAt), isTrue);
    });

    test('release allows next owner but never resets fencing counter', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      final first = (await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-a',
        now: start,
        leaseDuration: duration,
      ))!;
      expect(await store.release(lease: first, now: start), isTrue);
      final second = await store.acquire(
        operationId: 'install-1',
        ownerId: 'worker-b',
        now: start.add(const Duration(seconds: 1)),
        leaseDuration: duration,
      );
      expect(second!.fencingToken, greaterThan(first.fencingToken));
    });

    test('rejects empty identities and non-positive durations', () async {
      final store = InMemoryPluginInstallOperationLeaseStore();
      await expectLater(
        store.acquire(
          operationId: ' ',
          ownerId: 'worker',
          now: start,
          leaseDuration: duration,
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.acquire(
          operationId: 'install-1',
          ownerId: 'worker',
          now: start,
          leaseDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}

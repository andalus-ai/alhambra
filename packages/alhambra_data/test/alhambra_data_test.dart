import 'dart:convert';
import 'package:alhambra_data/alhambra_data.dart';
import 'package:test/test.dart';

void main() {
  group('1. Storage Subsystem', () {
    test('in-memory key/value storage', () async {
      final kv = InMemoryKeyValueStore();
      expect(await kv.read('key1'), isNull);

      await kv.write('key1', 'val1');
      expect(await kv.read('key1'), equals('val1'));

      await kv.remove('key1');
      expect(await kv.read('key1'), isNull);
    });

    test('local store with serialization', () async {
      final store = InMemoryLocalStore();
      await store.put<String>('user_pref', jsonEncode({'theme': 'dark'}));

      final exists = await store.contains('user_pref');
      expect(exists, isTrue);

      final raw = await store.get<String>('user_pref');
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['theme'], equals('dark'));

      await store.clear();
      expect(await store.contains('user_pref'), isFalse);
    });

    test('secure storage contract', () async {
      final secure = InMemorySecureStore();
      await secure.write('auth_token', 'jwt.secret.token');

      expect(await secure.read('auth_token'), equals('jwt.secret.token'));

      await secure.remove('auth_token');
      expect(await secure.read('auth_token'), isNull);
    });

    test('database contract and transaction', () async {
      final db = InMemoryDatabase();
      expect(db.isOpen, isFalse);

      await db.open();
      expect(db.isOpen, isTrue);

      await db.execute('CREATE TABLE workspaces (id TEXT);');
      expect(db.executedStatements, contains('CREATE TABLE workspaces (id TEXT);'));

      final result = await db.transaction((tx) async {
        await tx.execute('INSERT INTO workspaces VALUES ("ws-1");');
        return 'committed';
      });

      expect(result, equals('committed'));
      expect(db.executedStatements, contains('INSERT INTO workspaces VALUES ("ws-1");'));

      await db.close();
      expect(db.isOpen, isFalse);
    });
  });

  group('2. Cache Subsystem', () {
    test('memory cache basic operations', () async {
      final cache = MemoryCache();
      await cache.put<String>('profile', 'Alice');

      expect(await cache.get<String>('profile'), equals('Alice'));
      expect(cache.count, equals(1));

      await cache.remove('profile');
      expect(await cache.get<String>('profile'), isNull);
      expect(cache.count, equals(0));
    });

    test('TTL expiration', () async {
      final cache = MemoryCache();
      // Put with very short duration (1ms)
      await cache.put<String>(
        'temp_data',
        'transient',
        ttl: const Duration(milliseconds: 10),
      );

      expect(await cache.get<String>('temp_data'), equals('transient'));

      // Wait for TTL expiration
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(await cache.get<String>('temp_data'), isNull);
      expect(cache.count, equals(0));
    });

    test('cache policies enumeration', () {
      expect(CachePolicy.values, containsAll([
        CachePolicy.networkOnly,
        CachePolicy.cacheOnly,
        CachePolicy.cacheFirst,
        CachePolicy.networkFirst,
        CachePolicy.staleWhileRevalidate,
      ]));
    });
  });

  group('3. Connectivity Subsystem', () {
    test('connectivity monitor updates and streams status', () async {
      final monitor = SimpleConnectivityMonitor(
        initialStatus: ConnectivityStatus.online,
      );

      expect(monitor.currentStatus, equals(ConnectivityStatus.online));

      final states = <ConnectivityStatus>[];
      final subscription = monitor.status.listen(states.add);

      monitor.setStatus(ConnectivityStatus.offline);
      monitor.setStatus(ConnectivityStatus.online);

      // Wait for stream dispatch
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, equals([
        ConnectivityStatus.offline,
        ConnectivityStatus.online,
      ]));
      expect(monitor.currentStatus, equals(ConnectivityStatus.online));

      await subscription.cancel();
      monitor.dispose();
    });
  });

  group('4. Sync Subsystem', () {
    SyncOperation _op(String id, String operation) => SyncOperation(
          id: id,
          idempotencyKey: 'idem-$id',
          resourceType: 'workspace',
          resourceId: 'ws-$id',
          operation: operation,
          createdAt: DateTime.now(),
        );

    test('enqueue offline mutation and retrieve pending', () async {
      final queue = InMemoryOfflineQueue();
      final op1 = _op('sync-1', 'create');
      await queue.enqueue(op1);
      expect(await queue.count(), equals(1));

      final pending = await queue.pending();
      expect(pending.first.id, equals('sync-1'));
    });

    test('duplicate operation can be detected and ignored (Idempotency)',
        () async {
      final queue = InMemoryOfflineQueue();
      final op1 = _op('sync-dup', 'update');
      await queue.enqueue(op1);
      await queue.enqueue(op1); // Duplicate
      expect(await queue.count(), equals(1));
    });

    test('remove individual mutation and clear queue', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('sync-a', 'update'));
      await queue.enqueue(_op('sync-b', 'delete'));
      expect(await queue.count(), equals(2));

      await queue.remove('sync-a');
      expect(await queue.count(), equals(1));

      await queue.clear();
      expect(await queue.count(), equals(0));
    });

    test('sync engine replays mutations and keeps failed mutation recoverable',
        () async {
      final queue = InMemoryOfflineQueue();
      final opSuccess = _op('op-1', 'create');
      final opFail = _op('op-2', 'publish');

      await queue.enqueue(opSuccess);
      await queue.enqueue(opFail);

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (SyncOperation op) async {
          if (op.id == 'op-2') {
            return const DispatchResult.retrying('simulated failure');
          }
          return const DispatchResult.succeeded();
        },
      );

      final result = await engine.synchronize();

      expect(result.succeeded, equals(1));
      expect(result.failed, equals(1));

      // Retrying mutation remains in queue
      expect(await queue.count(), equals(1));
      final remaining = await queue.pending();
      expect(remaining.first.id, equals('op-2'));

      engine.dispose();
    });

    test('conflict resolvers are injectable and functional', () async {
      const serverWins = ServerWinsResolver<String>();
      const clientWins = ClientWinsResolver<String>();

      expect(await serverWins.resolve('local', 'remote'), equals('remote'));
      expect(await clientWins.resolve('local', 'remote'), equals('local'));

      final timestampResolver = TimestampConflictResolver<Map<String, dynamic>>(
        (item) => item['updatedAt'] as DateTime,
      );

      final t1 = DateTime(2026, 1, 1, 10, 0);
      final t2 = DateTime(2026, 1, 1, 12, 0);

      final localItem = {'val': 'local', 'updatedAt': t2};
      final remoteItem = {'val': 'remote', 'updatedAt': t1};

      final resolved = await timestampResolver.resolve(localItem, remoteItem);
      expect(resolved['val'], equals('local'));
    });
  });

  group('5. File Subsystem', () {
    test('local and object file store contract: upload, download, delete', () async {
      final fileStore = InMemoryFileStore();

      final upload = FileUpload(
        name: 'report.pdf',
        contentType: 'application/pdf',
        bytes: [0x25, 0x50, 0x44, 0x46], // %PDF
      );

      final ref = await fileStore.upload(upload);
      expect(ref.name, equals('report.pdf'));
      expect(ref.size, equals(4));

      final download = await fileStore.download(ref);
      expect(download.bytes, equals([0x25, 0x50, 0x44, 0x46]));
      expect(download.reference.id, equals(ref.id));

      await fileStore.delete(ref);
      expect(() => fileStore.download(ref), throwsA(isA<StateError>()));
    });
  });
}

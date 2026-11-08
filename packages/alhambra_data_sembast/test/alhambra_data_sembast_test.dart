import 'package:alhambra_data/alhambra_data.dart'
    show LocalRecord, SyncOperation, SyncOperationStatus, SyncRecordState;
import 'package:alhambra_data_sembast/alhambra_data_sembast.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:test/test.dart';

/// Opens a fresh in-memory database using a unique name per test group.
Future<sembast.Database> freshDb(String name) =>
    openSembastMemoryDatabase(name: name);

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // KeyValueStore
  // ══════════════════════════════════════════════════════════════════════════
  group('SembastKeyValueStore', () {
    late sembast.Database db;
    late SembastKeyValueStore kv;

    setUp(() async {
      db = await freshDb('kv_${DateTime.now().microsecondsSinceEpoch}');
      kv = SembastKeyValueStore(db);
    });

    tearDown(() => db.close());

    test('write and read returns value', () async {
      await kv.write('key1', 'hello');
      expect(await kv.read('key1'), 'hello');
    });

    test('read missing key returns null', () async {
      expect(await kv.read('missing'), isNull);
    });

    test('overwrite replaces previous value', () async {
      await kv.write('k', 'v1');
      await kv.write('k', 'v2');
      expect(await kv.read('k'), 'v2');
    });

    test('remove deletes the entry', () async {
      await kv.write('del', 'value');
      await kv.remove('del');
      expect(await kv.read('del'), isNull);
    });

    test('remove non-existent key is a no-op', () async {
      await expectLater(kv.remove('nonexistent'), completes);
    });

    test('multiple independent keys', () async {
      await kv.write('a', '1');
      await kv.write('b', '2');
      expect(await kv.read('a'), '1');
      expect(await kv.read('b'), '2');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LocalStore
  // ══════════════════════════════════════════════════════════════════════════
  group('SembastLocalStore', () {
    late sembast.Database db;
    late SembastLocalStore store;

    setUp(() async {
      db = await freshDb('ls_${DateTime.now().microsecondsSinceEpoch}');
      store = SembastLocalStore(db);
    });

    tearDown(() => db.close());

    test('put and get string', () async {
      await store.put<String>('name', 'Alice');
      expect(await store.get<String>('name'), 'Alice');
    });

    test('put and get int', () async {
      await store.put<int>('count', 42);
      expect(await store.get<int>('count'), 42);
    });

    test('put and get bool', () async {
      await store.put<bool>('flag', true);
      expect(await store.get<bool>('flag'), isTrue);
    });

    test('put and get map', () async {
      await store.put<Map<String, dynamic>>('user', {'name': 'Bob', 'age': 30});
      final result = await store.get<Map<String, dynamic>>('user');
      expect(result, isNotNull);
      expect(result!['name'], 'Bob');
      expect(result['age'], 30);
    });

    test('get missing key returns null', () async {
      expect(await store.get<String>('missing'), isNull);
    });

    test('delete removes entry', () async {
      await store.put<String>('tmp', 'data');
      await store.delete('tmp');
      expect(await store.get<String>('tmp'), isNull);
    });

    test('contains returns true for existing key', () async {
      await store.put<String>('exists', 'yes');
      expect(await store.contains('exists'), isTrue);
    });

    test('contains returns false for missing key', () async {
      expect(await store.contains('ghost'), isFalse);
    });

    test('clear removes all entries', () async {
      await store.put<String>('x', 'v1');
      await store.put<String>('y', 'v2');
      await store.clear();
      expect(await store.contains('x'), isFalse);
      expect(await store.contains('y'), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // OfflineQueue
  // ══════════════════════════════════════════════════════════════════════════
  group('SembastOfflineQueue', () {
    late sembast.Database db;
    late SembastOfflineQueue queue;

    SyncOperation makeOp(String id,
            {SyncOperationStatus status = SyncOperationStatus.pending}) =>
        SyncOperation(
          id: id,
          idempotencyKey: 'idem-$id',
          resourceType: 'workspace',
          resourceId: 'r-$id',
          operation: 'update',
          createdAt: DateTime.utc(2024, 1, 1),
          status: status,
        );

    setUp(() async {
      db = await freshDb('oq_${DateTime.now().microsecondsSinceEpoch}');
      queue = SembastOfflineQueue(db);
    });

    tearDown(() => db.close());

    test('enqueue and count', () async {
      await queue.enqueue(makeOp('1'));
      await queue.enqueue(makeOp('2'));
      expect(await queue.count(), 2);
    });

    test('pending returns pending and retrying only', () async {
      await queue.enqueue(makeOp('p', status: SyncOperationStatus.pending));
      await queue.enqueue(makeOp('r', status: SyncOperationStatus.retrying));
      await queue.enqueue(makeOp('s', status: SyncOperationStatus.succeeded));
      final pending = await queue.pending();
      expect(pending.map((o) => o.id).toSet(), containsAll(['p', 'r']));
      expect(pending.map((o) => o.id), isNot(contains('s')));
    });

    test('enqueue deduplicates by id', () async {
      await queue.enqueue(makeOp('dup'));
      await queue.enqueue(makeOp('dup'));
      expect(await queue.count(), 1);
    });

    test('updateStatus changes stored status', () async {
      await queue.enqueue(makeOp('u'));
      final updated = makeOp('u', status: SyncOperationStatus.retrying)
          .copyWith(attemptCount: 1);
      await queue.updateStatus(updated);
      final pending = await queue.pending();
      final found = pending.firstWhere((o) => o.id == 'u');
      expect(found.status, SyncOperationStatus.retrying);
      expect(found.attemptCount, 1);
    });

    test('updateStatus on unknown id is no-op', () async {
      await expectLater(queue.updateStatus(makeOp('nope')), completes);
    });

    test('remove deletes operation', () async {
      await queue.enqueue(makeOp('rm'));
      await queue.remove('rm');
      expect(await queue.count(), 0);
    });

    test('clear empties queue', () async {
      await queue.enqueue(makeOp('a'));
      await queue.enqueue(makeOp('b'));
      await queue.clear();
      expect(await queue.count(), 0);
      expect(await queue.pending(), isEmpty);
    });

    test('pending returns results in chronological order', () async {
      final early = SyncOperation(
        id: 'early',
        idempotencyKey: 'ie',
        resourceType: 'ws',
        resourceId: 'r1',
        operation: 'create',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final latOp = SyncOperation(
        id: 'late',
        idempotencyKey: 'il',
        resourceType: 'ws',
        resourceId: 'r2',
        operation: 'create',
        createdAt: DateTime.utc(2024, 6, 1),
      );
      await queue.enqueue(latOp);
      await queue.enqueue(early);
      final pending = await queue.pending();
      expect(pending.first.id, 'early');
      expect(pending.last.id, 'late');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LocalRecordStore
  // ══════════════════════════════════════════════════════════════════════════
  group('SembastLocalRecordStore', () {
    late sembast.Database db;
    late SembastLocalRecordStore store;

    LocalRecord makeRecord({
      String type = 'workspace',
      String id = 'w1',
      String? org = 'org-A',
      SyncRecordState state = SyncRecordState.synced,
      bool deleted = false,
      Map<String, Object?>? payload,
    }) =>
        LocalRecord(
          resourceType: type,
          resourceId: id,
          organizationId: org,
          updatedAt: DateTime.utc(2024, 1, 1),
          state: state,
          deleted: deleted,
          payload: payload ?? {'name': 'Test'},
        );

    setUp(() async {
      db = await freshDb('lr_${DateTime.now().microsecondsSinceEpoch}');
      store = SembastLocalRecordStore(db);
    });

    tearDown(() => db.close());

    test('save and get roundtrip', () async {
      await store.save(makeRecord());
      final got = await store.get(
          resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(got, isNotNull);
      expect(got!.resourceId, 'w1');
      expect(got.resourceType, 'workspace');
      expect(got.organizationId, 'org-A');
    });

    test('get returns null for unknown record', () async {
      expect(
        await store.get(resourceType: 'workspace', resourceId: 'nope'),
        isNull,
      );
    });

    test('save replaces existing record', () async {
      await store.save(makeRecord(payload: {'v': 1}));
      await store.save(makeRecord(payload: {'v': 2}));
      final got = await store.get(
          resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(got!.payload['v'], 2);
    });

    test('count reflects all stored records', () async {
      await store.save(makeRecord(id: 'r1'));
      await store.save(makeRecord(id: 'r2'));
      expect(await store.count, 2);
    });

    test('listForOrg excludes deleted tombstones', () async {
      await store.save(makeRecord(id: 'alive'));
      await store.save(makeRecord(id: 'dead', deleted: true));
      final list = await store.listForOrg('org-A');
      expect(list.map((r) => r.resourceId), contains('alive'));
      expect(list.map((r) => r.resourceId), isNot(contains('dead')));
    });

    test('listForOrg excludes other org records', () async {
      await store.save(makeRecord(id: 'a-rec', org: 'org-A'));
      await store.save(makeRecord(id: 'b-rec', org: 'org-B'));
      final listA = await store.listForOrg('org-A');
      expect(listA.every((r) => r.organizationId == 'org-A'), isTrue);
    });

    test('pendingSyncRecords returns only pendingSync state', () async {
      await store.save(makeRecord(id: 's', state: SyncRecordState.synced));
      await store.save(
          makeRecord(id: 'p', state: SyncRecordState.pendingSync));
      final pending = await store.pendingSyncRecords;
      expect(pending.length, 1);
      expect(pending.first.resourceId, 'p');
    });

    test('purge removes record permanently', () async {
      await store.save(makeRecord());
      await store.purge(
          resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(
        await store.get(
            resourceType: 'workspace',
            resourceId: 'w1',
            organizationId: 'org-A'),
        isNull,
      );
      expect(await store.count, 0);
    });

    test('cross-tenant isolation: same resourceId different org', () async {
      await store
          .save(makeRecord(id: 'shared', org: 'org-A', payload: {'owner': 'A'}));
      await store
          .save(makeRecord(id: 'shared', org: 'org-B', payload: {'owner': 'B'}));
      final a = await store.get(
          resourceType: 'workspace', resourceId: 'shared', organizationId: 'org-A');
      final b = await store.get(
          resourceType: 'workspace', resourceId: 'shared', organizationId: 'org-B');
      expect(a!.payload['owner'], 'A');
      expect(b!.payload['owner'], 'B');
    });
  });
}

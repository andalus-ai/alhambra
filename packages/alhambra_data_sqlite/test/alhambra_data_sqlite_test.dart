import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_data_sqlite/alhambra_data_sqlite.dart';
import 'package:test/test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<Sqlite3Database> _openDb() async {
  final db = Sqlite3Database.memory();
  await db.open();
  return db;
}

SyncOperation _op(String id, {SyncOperationStatus status = SyncOperationStatus.pending}) =>
    SyncOperation(
      id: id,
      idempotencyKey: 'ik-$id',
      resourceType: 'workspace',
      resourceId: 'r-$id',
      operation: 'create',
      createdAt: DateTime(2024, 1, 1, 0, 0, int.parse(id.replaceAll(RegExp(r'\D'), '0').padLeft(2, '0').substring(0, 2))),
      status: status,
      payload: {'key': 'value-$id'},
    );

LocalRecord _record(String id, {String orgId = 'org-A', SyncRecordState state = SyncRecordState.synced}) =>
    LocalRecord(
      resourceType: 'workspace',
      resourceId: id,
      organizationId: orgId,
      version: 1,
      updatedAt: DateTime(2024, 1, 1),
      state: state,
      payload: {'name': 'ws-$id'},
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Sqlite3Database ──────────────────────────────────────────────────────
  group('Sqlite3Database', () {
    late Sqlite3Database db;
    setUp(() async => db = await _openDb());
    tearDown(() async => db.close());

    test('open sets isOpen=true', () => expect(db.isOpen, isTrue));

    test('close sets isOpen=false', () async {
      await db.close();
      expect(db.isOpen, isFalse);
    });

    test('execute and query simple DDL + DML', () async {
      await db.execute('CREATE TABLE t (id TEXT, v INTEGER)');
      await db.execute("INSERT INTO t VALUES ('a', 1)");
      final rows = await db.query('SELECT * FROM t');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'a');
      expect(rows.first['v'], 1);
    });

    test('named parameters substituted correctly', () async {
      await db.execute('CREATE TABLE p (id TEXT, name TEXT)');
      await db.execute(
        'INSERT INTO p VALUES (:id, :name)',
        parameters: {'id': 'x1', 'name': 'Alice'},
      );
      final rows = await db.query(
        'SELECT name FROM p WHERE id = :id',
        parameters: {'id': 'x1'},
      );
      expect(rows.first['name'], 'Alice');
    });

    test('transaction commits on success', () async {
      await db.execute('CREATE TABLE tx (n INTEGER)');
      await db.transaction((tx) async {
        await tx.execute('INSERT INTO tx VALUES (42)');
      });
      final rows = await db.query('SELECT n FROM tx');
      expect(rows.first['n'], 42);
    });

    test('transaction rolls back on error', () async {
      await db.execute('CREATE TABLE rb (n INTEGER)');
      await expectLater(
        () => db.transaction((tx) async {
          await tx.execute('INSERT INTO rb VALUES (99)');
          throw Exception('boom');
        }),
        throwsException,
      );
      final rows = await db.query('SELECT COUNT(*) as c FROM rb');
      expect(rows.first['c'], 0);
    });

    test('query on closed db throws StateError', () async {
      await db.close();
      expect(() => db.query('SELECT 1'), throwsStateError);
    });

    test('InMemoryDatabase (fallback) still works', () async {
      final mem = InMemoryDatabase();
      await mem.open();
      expect(mem.isOpen, isTrue);
      await mem.close();
    });
  });

  // ── Sqlite3OfflineQueue ──────────────────────────────────────────────────
  group('Sqlite3OfflineQueue', () {
    late Sqlite3Database db;
    late Sqlite3OfflineQueue queue;

    setUp(() async {
      db = await _openDb();
      queue = Sqlite3OfflineQueue(db);
      await queue.init();
    });
    tearDown(() async => db.close());

    test('enqueue increases count', () async {
      await queue.enqueue(_op('1'));
      expect(await queue.count(), 1);
    });

    test('deduplicates by id', () async {
      await queue.enqueue(_op('1'));
      await queue.enqueue(_op('1'));
      expect(await queue.count(), 1);
    });

    test('pending returns only pending/retrying', () async {
      await queue.enqueue(_op('1'));
      await queue.enqueue(_op('2', status: SyncOperationStatus.conflict));
      await queue.enqueue(_op('3', status: SyncOperationStatus.retrying));
      final p = await queue.pending();
      expect(p.map((o) => o.id), containsAll(['1', '3']));
      expect(p.map((o) => o.id), isNot(contains('2')));
    });

    test('pending ordered FIFO by createdAt', () async {
      await queue.enqueue(_op('2'));
      await queue.enqueue(_op('1'));
      final ids = (await queue.pending()).map((o) => o.id).toList();
      expect(ids.first, '1');
    });

    test('updateStatus persists new status', () async {
      await queue.enqueue(_op('1'));
      final op = (await queue.pending()).first;
      await queue.updateStatus(op.copyWith(status: SyncOperationStatus.conflict));
      expect(await queue.pending(), isEmpty); // conflict not returned by pending()
    });

    test('remove deletes by id', () async {
      await queue.enqueue(_op('1'));
      await queue.remove('1');
      expect(await queue.count(), 0);
    });

    test('clear empties queue', () async {
      await queue.enqueue(_op('1'));
      await queue.enqueue(_op('2'));
      await queue.clear();
      expect(await queue.count(), 0);
    });

    test('payload round-trips through JSON', () async {
      final op = _op('1');
      await queue.enqueue(op);
      final loaded = (await queue.pending()).first;
      expect(loaded.payload, {'key': 'value-1'});
    });
  });

  // ── Sqlite3LocalStore ────────────────────────────────────────────────────
  group('Sqlite3LocalStore', () {
    late Sqlite3Database db;
    late Sqlite3LocalStore store;

    setUp(() async {
      db = await _openDb();
      store = Sqlite3LocalStore(db);
      await store.init();
    });
    tearDown(() async => db.close());

    test('put and get String', () async {
      await store.put('k', 'hello');
      expect(await store.get<String>('k'), 'hello');
    });

    test('put and get int', () async {
      await store.put('n', 42);
      expect(await store.get<int>('n'), 42);
    });

    test('put and get bool', () async {
      await store.put('b', true);
      expect(await store.get<bool>('b'), isTrue);
    });

    test('put and get Map', () async {
      await store.put('m', {'x': 1, 'y': 'two'});
      expect(await store.get<Map>('m'), {'x': 1, 'y': 'two'});
    });

    test('get returns null for missing key', () async {
      expect(await store.get<String>('missing'), isNull);
    });

    test('contains returns true/false correctly', () async {
      await store.put('exists', 1);
      expect(await store.contains('exists'), isTrue);
      expect(await store.contains('nope'), isFalse);
    });

    test('delete removes entry', () async {
      await store.put('del', 'bye');
      await store.delete('del');
      expect(await store.get<String>('del'), isNull);
    });

    test('clear removes all entries', () async {
      await store.put('a', 1);
      await store.put('b', 2);
      await store.clear();
      expect(await store.contains('a'), isFalse);
    });

    test('InMemoryLocalStore (fallback) still works', () async {
      final mem = InMemoryLocalStore();
      await mem.put('k', 'v');
      expect(await mem.get<String>('k'), 'v');
    });
  });

  // ── Sqlite3LocalRecordStore ──────────────────────────────────────────────
  group('Sqlite3LocalRecordStore', () {
    late Sqlite3Database db;
    late Sqlite3LocalRecordStore records;

    setUp(() async {
      db = await _openDb();
      records = Sqlite3LocalRecordStore(db);
      await records.init();
    });
    tearDown(() async => db.close());

    test('save and get round-trip', () async {
      await records.save(_record('w1'));
      final loaded = await records.get(resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(loaded, isNotNull);
      expect(loaded!.resourceId, 'w1');
      expect(loaded.payload['name'], 'ws-w1');
    });

    test('count reflects saved records', () async {
      await records.save(_record('w1'));
      await records.save(_record('w2'));
      expect(await records.count, 2);
    });

    test('listForOrg excludes tombstones', () async {
      await records.save(_record('w1'));
      await records.save(_record('w2', orgId: 'org-A').copyWith(deleted: true));
      final list = await records.listForOrg('org-A');
      expect(list.map((r) => r.resourceId), contains('w1'));
      expect(list.map((r) => r.resourceId), isNot(contains('w2')));
    });

    test('cross-tenant isolation: listForOrg only returns own org', () async {
      await records.save(_record('w1', orgId: 'org-A'));
      await records.save(_record('w2', orgId: 'org-B'));
      final orgA = await records.listForOrg('org-A');
      expect(orgA.map((r) => r.resourceId), contains('w1'));
      expect(orgA.map((r) => r.resourceId), isNot(contains('w2')));
    });

    test('pendingSyncRecords returns only pendingSync state', () async {
      await records.save(_record('w1', state: SyncRecordState.pendingSync));
      await records.save(_record('w2', state: SyncRecordState.synced));
      final pending = await records.pendingSyncRecords;
      expect(pending.map((r) => r.resourceId), contains('w1'));
      expect(pending.map((r) => r.resourceId), isNot(contains('w2')));
    });

    test('purge removes record by key', () async {
      await records.save(_record('w1', orgId: 'org-A'));
      await records.purge(resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(await records.count, 0);
    });

    test('save replaces existing record', () async {
      await records.save(_record('w1', state: SyncRecordState.synced));
      await records.save(_record('w1', state: SyncRecordState.conflict));
      final loaded = await records.get(resourceType: 'workspace', resourceId: 'w1', organizationId: 'org-A');
      expect(loaded!.state, SyncRecordState.conflict);
      expect(await records.count, 1);
    });

    test('InMemoryLocalRecordStore (fallback) still works', () async {
      final mem = InMemoryLocalRecordStore();
      mem.save(_record('w99'));
      expect(await mem.count, 1);
    });
  });
}

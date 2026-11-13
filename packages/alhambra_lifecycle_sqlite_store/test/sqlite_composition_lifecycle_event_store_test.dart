import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_lifecycle_store_test/alhambra_lifecycle_store_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late SqliteCompositionLifecycleEventStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-sqlite-events-');
  });

  tearDown(() async {
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  defineCompositionLifecycleEventStoreContractTests(
    name: 'SQLite',
    createStore: () async {
      store = SqliteCompositionLifecycleEventStore.open(
        path: '${directory.path}/lifecycle.sqlite',
      );
      return store;
    },
    disposeStore: (value) async {
      await (value as SqliteCompositionLifecycleEventStore).close();
    },
  );

  test('creates the schema and records its migration version', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/schema.sqlite',
    );
    final version = store.database.select('PRAGMA user_version').single['user_version'];
    expect(version, SqliteCompositionLifecycleEventStore.schemaVersion);
    expect(
      store.database.select(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_lifecycle_time'",
      ),
      isNotEmpty,
    );
  });

  test('rejects databases created by a newer schema version', () async {
    final path = '${directory.path}/future-schema.sqlite';
    final database = sqlite3.open(path);
    database.execute('PRAGMA user_version = ${SqliteCompositionLifecycleEventStore.schemaVersion + 1}');
    database.dispose();

    expect(
      () => SqliteCompositionLifecycleEventStore.open(path: path),
      throwsStateError,
    );
  });

  test('does not close a host-owned database', () async {
    final database = sqlite3.openInMemory();
    store = SqliteCompositionLifecycleEventStore(database: database);
    await store.close();

    database.select('SELECT 1 AS still_open');
    database.dispose();
  });

  test('reopens the database and retains committed events', () async {
    final path = '${directory.path}/reopen.sqlite';
    store = SqliteCompositionLifecycleEventStore.open(path: path);
    // Contract fixture is private to the shared suite; use the public codec
    // model directly to exercise durable restart behavior.
    const codec = CompositionLifecycleEventJsonCodec();
    final event = CompositionLifecycleEvent(
      eventId: 'reopen-event',
      correlationId: 'reopen-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 7, 1),
      nodeIds: const ['command:reopen'],
      ownerIds: const ['owner-reopen'],
    );
    await store.append(event);
    await store.close();

    store = SqliteCompositionLifecycleEventStore.open(path: path);
    final result = await store.query(CompositionLifecycleEventQuery());
    expect(result.single.eventId, event.eventId);
    expect(codec.encode(result.single), codec.encode(event));
  });

  test('worker owns SQLite on a separate isolate and supports append/query', () async {
    final worker = await SqliteLifecycleEventStoreWorker.open(
      path: '${directory.path}/worker.sqlite',
    );
    addTearDown(worker.close);
    final event = CompositionLifecycleEvent(
      eventId: 'worker-event',
      correlationId: 'worker-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 7, 2),
      nodeIds: const ['command:worker'],
      ownerIds: const ['owner-worker'],
    );

    await worker.append(event);
    final result = await worker.query(
      CompositionLifecycleEventQuery(ownerId: 'owner-worker'),
    );

    expect(result.single.eventId, event.eventId);
    expect(
      const CompositionLifecycleEventJsonCodec().encode(result.single),
      const CompositionLifecycleEventJsonCodec().encode(event),
    );
  });

  test('worker preserves identity conflicts across the isolate boundary', () async {
    final worker = await SqliteLifecycleEventStoreWorker.open(
      path: '${directory.path}/worker-conflict.sqlite',
    );
    addTearDown(worker.close);
    final event = CompositionLifecycleEvent(
      eventId: 'worker-conflict',
      correlationId: 'worker-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 7, 3),
      nodeIds: const ['command:worker'],
      ownerIds: const ['owner-worker'],
    );
    await worker.append(event);

    await expectLater(
      worker.append(CompositionLifecycleEvent(
        eventId: event.eventId,
        correlationId: 'different-correlation',
        operation: event.operation,
        status: event.status,
        timestamp: event.timestamp,
        nodeIds: event.nodeIds,
        ownerIds: event.ownerIds,
      )),
      throwsA(
        isA<CompositionLifecycleEventIdentityConflictException>()
            .having((error) => error.eventId, 'eventId', event.eventId),
      ),
    );
  });

  test('worker exposes WAL checkpoint counters', () async {
    final worker = await SqliteLifecycleEventStoreWorker.open(
      path: '${directory.path}/worker-checkpoint.sqlite',
    );
    addTearDown(worker.close);

    final result = await worker.checkpoint();

    expect(result.mode, SqliteWalCheckpointMode.passive);
    expect(result.busy, greaterThanOrEqualTo(0));
    expect(result.logFrames, greaterThanOrEqualTo(-1));
    expect(result.checkpointedFrames, greaterThanOrEqualTo(-1));
  });
  test('rolls back the event row when owner association insertion fails', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/rollback.sqlite',
    );
    store.database.execute('''
      CREATE TRIGGER reject_owner BEFORE INSERT ON lifecycle_event_owners
      BEGIN
        SELECT RAISE(ABORT, 'injected owner association failure');
      END
    ''');
    final event = CompositionLifecycleEvent(
      eventId: 'rollback-event',
      correlationId: 'rollback-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 7, 4),
      nodeIds: const ['command:rollback'],
      ownerIds: const ['owner-rollback'],
    );

    await expectLater(store.append(event), throwsA(isA<Exception>()));
    store.database.execute('DROP TRIGGER reject_owner');
    expect(await store.query(CompositionLifecycleEventQuery()), isEmpty);
  });

  test('recovers committed WAL data after closing and reopening', () async {
    final path = '${directory.path}/wal-recovery.sqlite';
    store = SqliteCompositionLifecycleEventStore.open(path: path);
    final event = CompositionLifecycleEvent(
      eventId: 'wal-recovery-event',
      correlationId: 'wal-recovery-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 7, 5),
      nodeIds: const ['command:wal-recovery'],
      ownerIds: const ['owner-wal-recovery'],
    );
    await store.append(event);
    await store.close();

    store = SqliteCompositionLifecycleEventStore.open(path: path);
    final recovered = await store.query(
      CompositionLifecycleEventQuery(ownerId: 'owner-wal-recovery'),
    );
    expect(recovered.single.eventId, event.eventId);
  });

}

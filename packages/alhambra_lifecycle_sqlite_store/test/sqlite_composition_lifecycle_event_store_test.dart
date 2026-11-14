import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_lifecycle_store_test/alhambra_lifecycle_store_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  SqliteCompositionLifecycleEventStore? store;

  setUp(() async {
    store = null;
    directory = await Directory.systemTemp.createTemp('alhambra-sqlite-events-');
  });

  tearDown(() async {
    await store?.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  defineCompositionLifecycleEventStoreContractTests(
    name: 'SQLite',
    createStore: () async {
      store = SqliteCompositionLifecycleEventStore.open(
        path: '${directory.path}/lifecycle.sqlite',
      );
      return store!;
    },
    disposeStore: (value) async {
      await (value as SqliteCompositionLifecycleEventStore).close();
    },
  );

  test('creates the schema and records its migration version', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/schema.sqlite',
    );
    final version = store!.database.select('PRAGMA user_version').single['user_version'];
    expect(version, SqliteCompositionLifecycleEventStore.schemaVersion);
    expect(
      store!.database.select(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_lifecycle_time'",
      ),
      isNotEmpty,
    );
  });

  test('upgrades a version 1 database through ordered migrations', () async {
    final path = '${directory.path}/upgrade-v1.sqlite';
    final database = sqlite3.open(path);
    database.execute('''
      CREATE TABLE lifecycle_events (
        event_id TEXT PRIMARY KEY NOT NULL,
        event_id_sort_key TEXT NOT NULL,
        correlation_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp_micros INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE lifecycle_event_owners (
        event_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        PRIMARY KEY (event_id, owner_id),
        FOREIGN KEY (event_id) REFERENCES lifecycle_events(event_id)
          ON DELETE CASCADE
      )
    ''');
    database.execute(
      'CREATE INDEX idx_lifecycle_time '
      'ON lifecycle_events(timestamp_micros, event_id_sort_key)',
    );
    database.execute(
      'CREATE INDEX idx_lifecycle_correlation_time '
      'ON lifecycle_events(correlation_id, timestamp_micros, event_id_sort_key)',
    );
    database.execute(
      'CREATE INDEX idx_lifecycle_operation_time '
      'ON lifecycle_events(operation, timestamp_micros, event_id_sort_key)',
    );
    database.execute(
      'CREATE INDEX idx_lifecycle_status_time '
      'ON lifecycle_events(status, timestamp_micros, event_id_sort_key)',
    );
    database.execute(
      'CREATE INDEX idx_lifecycle_owner_time '
      'ON lifecycle_event_owners(owner_id, event_id)',
    );
    database.execute('PRAGMA user_version = 1');
    database.dispose();

    store = SqliteCompositionLifecycleEventStore.open(path: path);

    expect(
      store!.database.select('PRAGMA user_version').single['user_version'],
      SqliteCompositionLifecycleEventStore.schemaVersion,
    );
    expect(
      store!.database.select(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name = 'idx_lifecycle_status_operation_time'",
      ),
      isNotEmpty,
    );
  });

  test('uses the composite status-operation index for matching queries', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/query-plan.sqlite',
    );
    final plan = store!.database.select(
      'EXPLAIN QUERY PLAN SELECT payload FROM lifecycle_events '
      'WHERE status = ? AND operation = ? '
      'ORDER BY timestamp_micros, event_id_sort_key LIMIT ?',
      ['succeeded', 'activate', 20],
    );
    expect(
      plan.map((row) => row['detail'].toString()).join(' '),
      contains('idx_lifecycle_status_operation_time'),
    );
  });

  test('compacts by inclusive time boundary and newest event count', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/compact.sqlite',
    );
    final base = DateTime.utc(2026, 8, 1);
    CompositionLifecycleEvent event(String id, int minutes) =>
        CompositionLifecycleEvent(
          eventId: id,
          correlationId: 'compact-correlation',
          operation: CompositionLifecycleOperation.activate,
          status: CompositionLifecycleStatus.succeeded,
          timestamp: base.add(Duration(minutes: minutes)),
          nodeIds: const ['command:compact'],
          ownerIds: ['owner-$id'],
        );

    await store!.append(event('old', 0));
    await store!.append(event('newest', 4));
    await store!.append(event('middle', 2));
    await store!.append(event('boundary', 1));

    final removedByTime = await store!.compact(
      retainFrom: base.add(const Duration(minutes: 1)),
    );
    expect(removedByTime, 1);
    final afterTimeFilter = await store!.query(CompositionLifecycleEventQuery());
    expect(
      afterTimeFilter.map((value) => value.eventId),
      ['boundary', 'middle', 'newest'],
    );

    final removedByCount = await store!.compact(maxEvents: 2);
    expect(removedByCount, 1);
    final retained = await store!.query(CompositionLifecycleEventQuery());
    expect(retained.map((value) => value.eventId), ['middle', 'newest']);
    expect(
      await store!.query(CompositionLifecycleEventQuery(ownerId: 'owner-old')),
      isEmpty,
    );
  });

  test('applies the time filter before the newest-event cap', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/compact-combined.sqlite',
    );
    final base = DateTime.utc(2026, 8, 4);
    for (var minute = 0; minute < 5; minute++) {
      await store!.append(CompositionLifecycleEvent(
        eventId: 'combined-$minute',
        correlationId: 'combined-correlation',
        operation: CompositionLifecycleOperation.activate,
        status: CompositionLifecycleStatus.succeeded,
        timestamp: base.add(Duration(minutes: minute)),
        nodeIds: const ['command:combined'],
        ownerIds: const ['owner-combined'],
      ));
    }

    final removed = await store!.compact(
      retainFrom: base.add(const Duration(minutes: 1)),
      maxEvents: 2,
    );
    expect(removed, 3);
    final retained = await store!.query(CompositionLifecycleEventQuery());
    expect(retained.map((value) => value.eventId), ['combined-3', 'combined-4']);
  });

  test('rolls back retention when a delete trigger rejects compaction', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/compact-rollback.sqlite',
    );
    final event = CompositionLifecycleEvent(
      eventId: 'compact-rollback-event',
      correlationId: 'compact-rollback-correlation',
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 8, 3),
      nodeIds: const ['command:compact-rollback'],
      ownerIds: const ['owner-compact-rollback'],
    );
    await store!.append(event);
    store!.database.execute('''
      CREATE TRIGGER reject_lifecycle_delete BEFORE DELETE ON lifecycle_events
      BEGIN
        SELECT RAISE(ABORT, 'injected retention failure');
      END
    ''');

    await expectLater(
      store!.compact(maxEvents: 1),
      throwsA(isA<Exception>()),
    );
    store!.database.execute('DROP TRIGGER reject_lifecycle_delete');
    final retained = await store!.query(CompositionLifecycleEventQuery());
    expect(retained.single.eventId, event.eventId);
    expect(
      await store!.query(
        CompositionLifecycleEventQuery(ownerId: 'owner-compact-rollback'),
      ),
      hasLength(1),
    );
  });

  test('rejects empty and invalid retention policies without mutation', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/compact-validation.sqlite',
    );
    await expectLater(store!.compact(), throwsArgumentError);
    await expectLater(store!.compact(maxEvents: 0), throwsArgumentError);
    expect(await store!.query(CompositionLifecycleEventQuery()), isEmpty);
  });

  test('worker compacts using the same retention semantics', () async {
    final worker = await SqliteLifecycleEventStoreWorker.open(
      path: '${directory.path}/worker-compact.sqlite',
    );
    addTearDown(worker.close);
    final base = DateTime.utc(2026, 8, 2);
    for (var i = 0; i < 5; i++) {
      await worker.append(CompositionLifecycleEvent(
        eventId: 'worker-retain-$i',
        correlationId: 'worker-retain-correlation',
        operation: CompositionLifecycleOperation.activate,
        status: CompositionLifecycleStatus.succeeded,
        timestamp: base.add(Duration(minutes: i)),
        nodeIds: const ['command:worker-retain'],
        ownerIds: const ['owner-worker-retain'],
      ));
    }

    final removed = await worker.compact(maxEvents: 2);
    expect(removed, 3);
    final retained = await worker.query(CompositionLifecycleEventQuery());
    expect(retained.map((value) => value.eventId), [
      'worker-retain-3',
      'worker-retain-4',
    ]);
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
    await store!.close();

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
    await store!.append(event);
    await store!.close();

    store = SqliteCompositionLifecycleEventStore.open(path: path);
    final result = await store!.query(CompositionLifecycleEventQuery());
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

  test('PASSIVE checkpoint respects a concurrent reader snapshot', () async {
    final path = '${directory.path}/wal-reader.sqlite';
    store = SqliteCompositionLifecycleEventStore.open(path: path);
    store!.database.execute('PRAGMA wal_autocheckpoint = 0');

    final reader = sqlite3.open(path);
    addTearDown(reader.dispose);
    reader.execute('BEGIN');
    reader.select('SELECT COUNT(*) FROM lifecycle_events');

    for (var i = 0; i < 12; i++) {
      await store!.append(CompositionLifecycleEvent(
        eventId: 'reader-pinned-$i',
        correlationId: 'reader-pinned-correlation',
        operation: CompositionLifecycleOperation.activate,
        status: CompositionLifecycleStatus.succeeded,
        timestamp: DateTime.utc(2026, 9, 1).add(Duration(microseconds: i)),
        nodeIds: const ['command:reader-pinned'],
        ownerIds: const ['owner-reader-pinned'],
      ));
    }

    final whileReaderOpen = store!.checkpoint(
      mode: SqliteWalCheckpointMode.passive,
    );
    expect(whileReaderOpen.logFrames, greaterThan(0));
    expect(
      whileReaderOpen.checkpointedFrames,
      lessThan(whileReaderOpen.logFrames),
    );

    reader.execute('COMMIT');
    final afterReaderRelease = store!.checkpoint(
      mode: SqliteWalCheckpointMode.full,
    );
    expect(afterReaderRelease.busy, 0);
    expect(afterReaderRelease.fullyCheckpointed, isTrue);
    expect(
      await store!.query(CompositionLifecycleEventQuery()),
      hasLength(12),
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
  test('worker checkpoint reports reader-pinned WAL frames', () async {
    final path = '${directory.path}/worker-wal-reader.sqlite';
    final worker = await SqliteLifecycleEventStoreWorker.open(path: path);
    addTearDown(worker.close);

    final reader = sqlite3.open(path);
    addTearDown(reader.dispose);
    reader.execute('BEGIN');
    reader.select('SELECT COUNT(*) FROM lifecycle_events');

    for (var i = 0; i < 8; i++) {
      await worker.append(CompositionLifecycleEvent(
        eventId: 'worker-reader-pinned-$i',
        correlationId: 'worker-reader-pinned-correlation',
        operation: CompositionLifecycleOperation.activate,
        status: CompositionLifecycleStatus.succeeded,
        timestamp: DateTime.utc(2026, 9, 2).add(Duration(microseconds: i)),
        nodeIds: const ['command:worker-reader-pinned'],
        ownerIds: const ['owner-worker-reader-pinned'],
      ));
    }

    final pinned = await worker.checkpoint(
      mode: SqliteWalCheckpointMode.passive,
    );
    expect(pinned.logFrames, greaterThan(0));
    expect(pinned.checkpointedFrames, lessThan(pinned.logFrames));

    reader.execute('COMMIT');
    final released = await worker.checkpoint(
      mode: SqliteWalCheckpointMode.full,
    );
    expect(released.busy, 0);
    expect(released.fullyCheckpointed, isTrue);
  });

  test('rolls back the event row when owner association insertion fails', () async {
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/rollback.sqlite',
    );
    store!.database.execute('''
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

    await expectLater(store!.append(event), throwsA(isA<Exception>()));
    store!.database.execute('DROP TRIGGER reject_owner');

    // Reopen to prove the failed transaction left no durable event row.
    await store!.close();
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/rollback.sqlite',
    );
    expect(await store!.query(CompositionLifecycleEventQuery()), isEmpty);
    expect(
      await store!.query(
        CompositionLifecycleEventQuery(ownerId: 'owner-rollback'),
      ),
      isEmpty,
    );
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
    await store!.append(event);
    await store!.close();

    store = SqliteCompositionLifecycleEventStore.open(path: path);
    final recovered = await store!.query(
      CompositionLifecycleEventQuery(ownerId: 'owner-wal-recovery'),
    );
    expect(recovered.single.eventId, event.eventId);
  });

  test('reports SQLite database footprint and record count', () async {
    store = SqliteCompositionLifecycleEventStore.open(path: '${directory.path}/health.sqlite');
    await store!.append(CompositionLifecycleEvent(eventId: 'health-event', correlationId: 'health-correlation', operation: CompositionLifecycleOperation.activate, status: CompositionLifecycleStatus.succeeded, timestamp: DateTime.utc(2026, 9, 1), nodeIds: const ['command:health'], ownerIds: const ['owner-health']));
    final health = await store!.inspectHealth();
    expect(health.state, CompositionLifecycleStorageHealthState.healthy);
    expect(health.recordCount, 1);
    expect(health.primaryStorageBytes, greaterThan(0));
    expect(health.lastSuccessfulWriteAt, isNotNull);
    expect(health.metrics['adapter'], 'sqlite');
  });

  test('reports SQLite worker health through the isolate boundary', () async {
    final worker = await SqliteLifecycleEventStoreWorker.open(path: '${directory.path}/worker-health.sqlite');
    addTearDown(worker.close);
    await worker.append(CompositionLifecycleEvent(eventId: 'worker-health-event', correlationId: 'worker-health-correlation', operation: CompositionLifecycleOperation.activate, status: CompositionLifecycleStatus.succeeded, timestamp: DateTime.utc(2026, 9, 2), nodeIds: const ['command:worker-health'], ownerIds: const ['owner-worker-health']));
    final health = await worker.inspectHealth();
    expect(health.state, CompositionLifecycleStorageHealthState.healthy);
    expect(health.recordCount, 1);
    expect(health.primaryStorageBytes, greaterThan(0));
  });

}

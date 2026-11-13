import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_lifecycle_store_test/alhambra_lifecycle_store_test.dart';
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
}

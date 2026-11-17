library alhambra_lifecycle_store_test;

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

typedef LifecycleStoreFactory = Future<CompositionLifecycleEventStore> Function();
typedef LifecycleStoreDisposer = Future<void> Function(
  CompositionLifecycleEventStore store,
);

/// Defines the portable behavioral contract every lifecycle store must pass.
///
/// Call this from an adapter's test suite and provide a fresh store factory.
/// The tests intentionally assert API-level behavior only; adapter-specific
/// durability, migration, crash recovery, and compaction belong in adapter
/// tests.
void defineCompositionLifecycleEventStoreContractTests({
  required String name,
  required LifecycleStoreFactory createStore,
  required LifecycleStoreDisposer disposeStore,
}) {
  group('$name lifecycle store contract', () {
    late CompositionLifecycleEventStore store;

    setUp(() async {
      store = await createStore();
    });

    tearDown(() async {
      await disposeStore(store);
    });

    test('appends and returns events in stable chronological order', () async {
      final timestamp = DateTime.utc(2026, 1, 1);
      final events = [
        _event('late', timestamp.add(const Duration(minutes: 2)), eventId: 'c'),
        _event('early', timestamp, eventId: 'a'),
        _event('middle', timestamp.add(const Duration(minutes: 1)), eventId: 'b'),
      ];
      for (final event in events) {
        await store.append(event);
      }

      final result = await store.query(CompositionLifecycleEventQuery());
      expect(result.map((event) => event.eventId), ['a', 'b', 'c']);
    });

    test('applies inclusive time bounds and all identity filters', () async {
      final start = DateTime.utc(2026, 2, 1);
      await store.append(_event(
        'first', start, eventId: 'first', ownerIds: const ['owner-a'],
      ));
      await store.append(_event(
        'second', start.add(const Duration(hours: 1)),
        eventId: 'second', ownerIds: const ['owner-a', 'owner-b'],
        operation: CompositionLifecycleOperation.activate,
      ));
      await store.append(_event(
        'third', start.add(const Duration(hours: 2)),
        eventId: 'third', ownerIds: const ['owner-b'],
        operation: CompositionLifecycleOperation.deactivate,
        status: CompositionLifecycleStatus.failed,
      ));

      final result = await store.query(CompositionLifecycleEventQuery(
        ownerId: 'owner-a',
        correlationId: 'second',
        operation: CompositionLifecycleOperation.activate,
        status: CompositionLifecycleStatus.succeeded,
        from: start.add(const Duration(hours: 1)),
        to: start.add(const Duration(hours: 1)),
      ));
      expect(result.map((event) => event.eventId), ['second']);
    });

    test('supports exclusive composite cursors with equal timestamps', () async {
      final timestamp = DateTime.utc(2026, 3, 1);
      for (final id in ['d', 'b', 'a', 'c']) {
        await store.append(_event('same-$id', timestamp, eventId: id));
      }

      final first = await store.query(
        CompositionLifecycleEventQuery(limit: 2),
      );
      expect(first.map((event) => event.eventId), ['a', 'b']);

      final next = await store.query(CompositionLifecycleEventQuery(
        after: CompositionLifecycleEventCursor(
          timestamp: timestamp,
          eventId: first.last.eventId,
        ),
        limit: 2,
      ));
      expect(next.map((event) => event.eventId), ['c', 'd']);

      final previous = await store.query(CompositionLifecycleEventQuery(
        beforeCursor: CompositionLifecycleEventCursor(
          timestamp: timestamp,
          eventId: 'c',
        ),
        limit: 2,
      ));
      expect(previous.map((event) => event.eventId), ['a', 'b']);
    });

    test('uses Dart string ordering for Unicode event IDs', () async {
      final timestamp = DateTime.utc(2026, 3, 2);
      const supplementary = '\u{10000}';
      const privateUse = '\uE000';
      await store.append(_event('supplementary', timestamp, eventId: supplementary));
      await store.append(_event('private-use', timestamp, eventId: privateUse));

      final result = await store.query(CompositionLifecycleEventQuery());
      expect(result.map((event) => event.eventId), [supplementary, privateUse]);
    });

    test('treats identical retries as no-op and rejects conflicting IDs', () async {
      final event = _event(
        'retry', DateTime.utc(2026, 4, 1), eventId: 'stable-id',
      );
      await store.append(event);
      await store.append(event);

      expect(
        () => store.append(_event(
          'different', DateTime.utc(2026, 4, 2), eventId: 'stable-id',
        )),
        throwsA(isA<CompositionLifecycleEventIdentityConflictException>()),
      );
      final result = await store.query(CompositionLifecycleEventQuery());
      expect(result, hasLength(1));
      expect(result.single.correlationId, 'retry');
    });

    test('returns immutable result pages', () async {
      await store.append(_event(
        'immutable', DateTime.utc(2026, 5, 1), eventId: 'immutable',
      ));
      final result = await store.query(CompositionLifecycleEventQuery());
      expect(
        () => result.add(_event(
          'not-allowed', DateTime.utc(2026, 5, 2), eventId: 'mutate',
        )),
        throwsUnsupportedError,
      );
    });
  });
}

CompositionLifecycleEvent _event(
  String correlationId,
  DateTime timestamp, {
  required String eventId,
  List<String> ownerIds = const ['owner-a'],
  CompositionLifecycleOperation operation = CompositionLifecycleOperation.activate,
  CompositionLifecycleStatus status = CompositionLifecycleStatus.succeeded,
}) =>
    CompositionLifecycleEvent(
      eventId: eventId,
      correlationId: correlationId,
      operation: operation,
      status: status,
      timestamp: timestamp,
      nodeIds: const ['command:contract'],
      ownerIds: ownerIds,
    );


typedef MaintenanceAuditStoreFactory =
    Future<CompositionLifecycleStorageMaintenanceAuditStore> Function();
typedef MaintenanceAuditStoreDisposer =
    Future<void> Function(CompositionLifecycleStorageMaintenanceAuditStore store);

/// Defines the shared behavioral contract for durable maintenance audit stores.
///
/// Adapter-specific file recovery, SQLite migrations, durability guarantees,
/// and process coordination remain in each adapter's own test suite.
void defineCompositionLifecycleStorageMaintenanceAuditStoreContractTests({
  required String name,
  required MaintenanceAuditStoreFactory createStore,
  required MaintenanceAuditStoreDisposer disposeStore,
}) {
  group('$name maintenance audit contract', () {
    late CompositionLifecycleStorageMaintenanceAuditStore store;
    final requestedAt = DateTime.utc(2026, 11, 17, 1);
    final startedAt = DateTime.utc(2026, 11, 17, 1, 0, 1);

    CompositionLifecycleStorageMaintenanceOperationRecord record(
      String id,
      CompositionLifecycleStorageMaintenanceOperationStatus status, {
      DateTime? completedAt,
      int maxEvents = 100,
    }) =>
        CompositionLifecycleStorageMaintenanceOperationRecord(
          operationId: id,
          status: status,
          requestedAt: requestedAt,
          startedAt: startedAt,
          completedAt: completedAt,
          request: CompositionLifecycleStorageMaintenanceRequest(
            maxEvents: maxEvents,
          ),
          result: status ==
                  CompositionLifecycleStorageMaintenanceOperationStatus.started
              ? null
              : CompositionLifecycleStorageMaintenanceResult(
                  startedAt: startedAt,
                  completedAt: completedAt!,
                  recordsRemoved: 2,
                  checkpointRequested: false,
                ),
        );

    setUp(() async {
      store = await createStore();
    });

    tearDown(() async {
      await disposeStore(store);
    });

    test('supports idempotent start and terminal appends', () async {
      final start = record(
        'contract-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      );
      final terminal = record(
        'contract-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
        completedAt: startedAt.add(const Duration(seconds: 1)),
      );
      await store.append(start);
      await store.append(start);
      await store.append(terminal);
      await store.append(terminal);

      final records = await store.query(
        CompositionLifecycleStorageMaintenanceAuditQuery(
          operationId: 'contract-operation',
        ),
      );
      expect(records.map((value) => value.status), [
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      ]);
    });

    test('rejects conflicting identity reuse and a second terminal result', () async {
      await store.append(record(
        'conflict-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      await expectLater(
        store.append(record(
          'conflict-operation',
          CompositionLifecycleStorageMaintenanceOperationStatus.started,
          maxEvents: 200,
        )),
        throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
      );
      await store.append(record(
        'conflict-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
        completedAt: startedAt.add(const Duration(seconds: 1)),
      ));
      await expectLater(
        store.append(record(
          'conflict-operation',
          CompositionLifecycleStorageMaintenanceOperationStatus.failed,
          completedAt: startedAt.add(const Duration(seconds: 2)),
        )),
        throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
      );
    });

    test('applies operation, status and inclusive time filters before limit', () async {
      await store.append(record(
        'filter-a',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      await store.append(record(
        'filter-b',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      await store.append(record(
        'filter-b',
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
        completedAt: startedAt.add(const Duration(seconds: 1)),
      ));

      final page = await store.query(
        CompositionLifecycleStorageMaintenanceAuditQuery(
          operationId: 'filter-b',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
          from: startedAt,
          to: startedAt,
          limit: 1,
        ),
      );
      expect(page.map((value) => value.operationId), ['filter-b']);
    });

    test('uses an exclusive stable cursor for equal timestamps', () async {
      for (final id in ['d', 'b', 'a', 'c']) {
        await store.append(record(
          id,
          CompositionLifecycleStorageMaintenanceOperationStatus.started,
        ));
      }
      final first = await store.query(
        CompositionLifecycleStorageMaintenanceAuditQuery(limit: 2),
      );
      expect(first.map((value) => value.operationId), ['a', 'b']);
      final next = await store.query(
        CompositionLifecycleStorageMaintenanceAuditQuery(
          after: CompositionLifecycleStorageMaintenanceAuditCursor(
            startedAt: startedAt,
            operationId: first.last.operationId,
            status: first.last.status,
          ),
          limit: 2,
        ),
      );
      expect(next.map((value) => value.operationId), ['c', 'd']);
    });

    test('classifies unknown and completed outcomes conservatively', () async {
      await store.append(record(
        'unknown-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      final unknown = await store.inspectRecovery('unknown-operation');
      expect(
        unknown.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.outcomeUnknown,
      );
      expect(unknown.requiresReconciliation, isTrue);
      expect(unknown.automaticRetryAllowed, isFalse);

      await store.append(record(
        'completed-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      await store.append(record(
        'completed-operation',
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
        completedAt: startedAt.add(const Duration(seconds: 1)),
      ));
      final completed = await store.inspectRecovery('completed-operation');
      expect(
        completed.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.completed,
      );
      expect(
        completed.terminalStatus,
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      );
      expect(completed.automaticRetryAllowed, isFalse);
    });

    test('reports missing and terminal-only histories', () async {
      expect(
        (await store.inspectRecovery('absent')).state,
        CompositionLifecycleStorageMaintenanceRecoveryState.notFound,
      );
      await store.append(record(
        'terminal-only',
        CompositionLifecycleStorageMaintenanceOperationStatus.failed,
        completedAt: startedAt.add(const Duration(seconds: 1)),
      ));
      expect(
        (await store.inspectRecovery('terminal-only')).state,
        CompositionLifecycleStorageMaintenanceRecoveryState.incompleteHistory,
      );
    });

    test('returns immutable query pages', () async {
      await store.append(record(
        'immutable',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
      final page = await store.query(
        CompositionLifecycleStorageMaintenanceAuditQuery(),
      );
      expect(
        () => page.add(record(
          'mutate',
          CompositionLifecycleStorageMaintenanceOperationStatus.started,
        )),
        throwsUnsupportedError,
      );
    });
  });
}

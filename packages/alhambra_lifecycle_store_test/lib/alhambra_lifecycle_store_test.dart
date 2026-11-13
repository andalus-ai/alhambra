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
      final result = await store.query(const CompositionLifecycleEventQuery());
      expect(result, hasLength(1));
      expect(result.single.correlationId, 'retry');
    });

    test('returns immutable result pages', () async {
      await store.append(_event(
        'immutable', DateTime.utc(2026, 5, 1), eventId: 'immutable',
      ));
      final result = await store.query(const CompositionLifecycleEventQuery());
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

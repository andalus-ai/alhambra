import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File file;
  late JsonlCompositionLifecycleEventStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-events-');
    file = File('${directory.path}/events/lifecycle.jsonl');
    store = JsonlCompositionLifecycleEventStore(file: file);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('appends events and replays them through a new store instance', () async {
    final first = _event('c1', DateTime.utc(2026, 1, 1));
    final second = _event('c2', DateTime.utc(2026, 1, 2));

    await Future.wait([store.append(first), store.append(second)]);
    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final result = await reopened.query(CompositionLifecycleEventQuery());

    expect(result.map((event) => event.correlationId), ['c1', 'c2']);
  });

  test('filters by owner, correlation, operation, and time range', () async {
    await store.append(_event('one', DateTime.utc(2026, 1, 1)));
    await store.append(_event('two', DateTime.utc(2026, 1, 2)));
    await store.append(_event('three', DateTime.utc(2026, 1, 3)));

    final result = await store.query(CompositionLifecycleEventQuery(
      ownerId: 'owner-a',
      correlationId: 'two',
      operation: CompositionLifecycleOperation.activate,
      from: DateTime.utc(2026, 1, 2),
      to: DateTime.utc(2026, 1, 3),
      before: DateTime.utc(2026, 1, 3),
    ));

    expect(result.map((event) => event.correlationId), ['two']);
  });

  test('ignores an incomplete trailing record after an interrupted write', () async {
    await store.append(_event('valid', DateTime.utc(2026, 1, 1)));
    await file.writeAsString('{"schemaVersion":1,"partial":', mode: FileMode.append);

    final result = await store.query(CompositionLifecycleEventQuery());

    expect(result.map((event) => event.correlationId), ['valid']);
  });

  test('fails on malformed complete records rather than hiding corruption', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('not-json\n');

    expect(
      () => store.query(CompositionLifecycleEventQuery()),
      throwsFormatException,
    );
  });

  test('uses stable event ids to page through equal timestamps', () async {
    final timestamp = DateTime.utc(2026, 4, 5);
    for (final id in ['d', 'b', 'a', 'c']) {
      await store.append(_event('same-time-$id', timestamp, eventId: id));
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

  test('decodes schema v1 records with a stable legacy identity', () async {
    await file.parent.create(recursive: true);
    const legacy = '{"schemaVersion":1,"correlationId":"legacy","operation":"activate","status":"succeeded","timestamp":"2026-01-01T00:00:00.000Z","nodeIds":["command:save"],"ownerIds":["owner-a"]}';
    await file.writeAsString('$legacy\\n');

    final firstRead = await store.query(CompositionLifecycleEventQuery());
    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final secondRead = await reopened.query(CompositionLifecycleEventQuery());

    expect(firstRead.single.eventId, startsWith('legacy-'));
    expect(secondRead.single.eventId, firstRead.single.eventId);
  });

  test('returns immutable query results and applies limit', () async {
    await store.append(_event('one', DateTime.utc(2026, 1, 1)));
    await store.append(_event('two', DateTime.utc(2026, 1, 2)));

    final result = await store.query(
      CompositionLifecycleEventQuery(limit: 1),
    );

    expect(result, hasLength(1));
    expect(() => result.add(_event('x', DateTime.utc(2026))), throwsUnsupportedError);
  });
}

CompositionLifecycleEvent _event(String id, DateTime timestamp, {String? eventId}) =>
    CompositionLifecycleEvent(
      eventId: eventId,
      correlationId: id,
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: timestamp,
      nodeIds: const ['command:save'],
      ownerIds: const ['owner-a'],
    );

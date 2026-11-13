import 'dart:convert';
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
    expect(result.map((event) => event.eventId), [first.eventId, second.eventId]);
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
    await file.writeAsString('$legacy\n');

    final firstRead = await store.query(CompositionLifecycleEventQuery());
    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final secondRead = await reopened.query(CompositionLifecycleEventQuery());

    expect(firstRead.single.eventId, startsWith('legacy-'));
    expect(secondRead.single.eventId, firstRead.single.eventId);
  });

  test('treats identical event retries as idempotent', () async {
    final event = _event(
      'retry-me',
      DateTime.utc(2026, 5, 1),
      eventId: 'stable-event-id',
    );

    await store.append(event);
    final lengthAfterFirstAppend = await file.length();
    await store.append(event);

    expect(await file.length(), lengthAfterFirstAppend);
    expect(
      (await store.query(CompositionLifecycleEventQuery())).map((e) => e.eventId),
      ['stable-event-id'],
    );
  });

  test('rejects reuse of an event id for a different payload', () async {
    await store.append(_event(
      'first-payload',
      DateTime.utc(2026, 5, 1),
      eventId: 'reused-id',
    ));

    expect(
      () => store.append(_event(
        'different-payload',
        DateTime.utc(2026, 5, 2),
        eventId: 'reused-id',
      )),
      throwsA(isA<LifecycleEventIdentityConflictException>()),
    );
    expect(
      (await store.query(CompositionLifecycleEventQuery()))
          .single.correlationId,
      'first-payload',
    );
  });

  test('rebuilds the in-memory query index after reopening', () async {
    await store.append(_event('owner-one', DateTime.utc(2026, 5, 1)));
    await store.append(_event('owner-two', DateTime.utc(2026, 5, 2)));

    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final result = await reopened.query(
      CompositionLifecycleEventQuery(ownerId: 'owner-a', limit: 10),
    );

    expect(result.map((event) => event.correlationId), ['owner-one', 'owner-two']);
  });

  test('persists sparse checkpoints and resumes from the indexed prefix', () async {
    final events = List.generate(
      128 + 7,
      (index) => _event(
        'checkpoint-$index',
        DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        eventId: 'checkpoint-event-$index',
      ),
    );
    for (final event in events) {
      await store.append(event);
    }

    final sidecar = File('${file.path}.sparse-index.json');
    expect(await sidecar.exists(), isTrue);
    final checkpoint = jsonDecode(await sidecar.readAsString()) as Map;
    expect(checkpoint['schemaVersion'], 1);
    expect((checkpoint['blocks'] as List), hasLength(1));

    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final result = await reopened.query(
      CompositionLifecycleEventQuery(
        from: DateTime.utc(2026, 1, 1).add(const Duration(minutes: 125)),
        limit: 20,
      ),
    );
    expect(result.map((event) => event.eventId), [
      for (var index = 125; index < events.length; index++)
        'checkpoint-event-$index',
    ]);
  });

  test('rebuilds a damaged sparse index without losing log records', () async {
    for (var index = 0; index < 128 + 2; index++) {
      await store.append(_event(
        'damaged-index-$index',
        DateTime.utc(2026, 2, 1).add(Duration(seconds: index)),
        eventId: 'damaged-event-$index',
      ));
    }

    final sidecar = File('${file.path}.sparse-index.json');
    await sidecar.writeAsString('{not-json');
    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final result = await reopened.query(
      CompositionLifecycleEventQuery(limit: 200),
    );
    expect(result, hasLength(128 + 2));
    expect(result.first.eventId, 'damaged-event-0');
    expect(result.last.eventId, 'damaged-event-129');
  });

  test('uses block time ranges without assuming append timestamp order', () async {
    final base = DateTime.utc(2026, 3, 1);
    for (var index = 0; index < 128; index++) {
      final minute = index.isEven ? index : 1000 - index;
      await store.append(_event(
        'unordered-$index',
        base.add(Duration(minutes: minute)),
        eventId: 'unordered-event-$index',
      ));
    }

    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final result = await reopened.query(CompositionLifecycleEventQuery(
      from: base.add(const Duration(minutes: 990)),
      to: base.add(const Duration(minutes: 1000)),
      limit: 20,
    ));
    expect(result, isNotEmpty);
    expect(result, everyElement(
      predicate<CompositionLifecycleEvent>((event) =>
        !event.timestamp.isBefore(base.add(const Duration(minutes: 990))) &&
        !event.timestamp.isAfter(base.add(const Duration(minutes: 1000)))),
    ));
  });

  test('deduplicates an event id found in a persisted sparse block', () async {
    for (var index = 0; index < 128; index++) {
      await store.append(_event(
        'block-event-$index',
        DateTime.utc(2026, 4, 1).add(Duration(seconds: index)),
        eventId: 'block-id-$index',
      ));
    }
    final reopened = JsonlCompositionLifecycleEventStore(file: file);
    final duplicate = _event(
      'block-event-64',
      DateTime.utc(2026, 4, 1).add(const Duration(seconds: 64)),
      eventId: 'block-id-64',
    );
    final length = await file.length();
    await reopened.append(duplicate);
    expect(await file.length(), length);

    expect(
      () => reopened.append(_event(
        'conflicting-block-event',
        DateTime.utc(2026, 4, 2),
        eventId: 'block-id-64',
      )),
      throwsA(isA<LifecycleEventIdentityConflictException>()),
    );
  });

  test('invalidates sparse checkpoints after compaction', () async {
    for (var index = 0; index < 128; index++) {
      await store.append(_event(
        'compact-event-$index',
        DateTime.utc(2026, 5, 1).add(Duration(seconds: index)),
        eventId: 'compact-id-$index',
      ));
    }
    final sidecar = File('${file.path}.sparse-index.json');
    expect(await sidecar.exists(), isTrue);

    final removed = await store.compact(maxEvents: 100);
    expect(removed, 28);
    expect(await sidecar.exists(), isFalse);

    final result = await store.query(CompositionLifecycleEventQuery(limit: 200));
    expect(result, hasLength(100));
    expect(result.first.eventId, 'compact-id-28');
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

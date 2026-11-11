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

CompositionLifecycleEvent _event(String id, DateTime timestamp) =>
    CompositionLifecycleEvent(
      correlationId: id,
      operation: CompositionLifecycleOperation.activate,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: timestamp,
      nodeIds: const ['command:save'],
      ownerIds: const ['owner-a'],
    );

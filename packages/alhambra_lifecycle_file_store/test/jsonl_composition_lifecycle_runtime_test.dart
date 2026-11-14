import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-runtime-events-');
    file = File('${directory.path}/lifecycle/events.jsonl');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('wires runtime lifecycle events to durable storage', () async {
    final diagnostics = JsonlCompositionLifecycleRuntime(file: file);
    final transaction = diagnostics.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
      correlationId: 'integration-transaction',
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));

    expect(transaction.commit(), isA<CompositionSuccess>());
    expect(diagnostics.pendingEventCount, greaterThanOrEqualTo(0));

    await diagnostics.flush();
    final events = await diagnostics.query(CompositionLifecycleEventQuery());

    expect(events, hasLength(4));
    expect(events.map((event) => event.operation), [
      CompositionLifecycleOperation.prepare,
      CompositionLifecycleOperation.prepare,
      CompositionLifecycleOperation.activate,
      CompositionLifecycleOperation.activate,
    ]);
    expect(events.every((event) =>
        event.correlationId == 'integration-transaction'), isTrue);
    expect(events.every((event) =>
        event.ownerIds.contains('search-plugin')), isTrue);

    await diagnostics.close();
  });

  test('flushes accepted events before applying retention compaction', () async {
    final diagnostics = JsonlCompositionLifecycleRuntime(file: file);
    final transaction = diagnostics.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
      correlationId: 'keep-newest',
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));

    transaction.commit();

    final removed = await diagnostics.compact(maxEvents: 2);
    expect(removed, 2);

    final events = await diagnostics.query(CompositionLifecycleEventQuery());
    expect(events, hasLength(2));
    expect(events.map((event) => event.status), [
      CompositionLifecycleStatus.succeeded,
      CompositionLifecycleStatus.succeeded,
    ]);

    await diagnostics.close();
  });

  test('close drains accepted events and rejects late journal events', () async {
    final diagnostics = JsonlCompositionLifecycleRuntime(file: file);
    final transaction = diagnostics.runtime.beginTransaction(
      lifecycle: _Lifecycle(),
    )..stage(ServiceNode(serviceId: 'index', ownerId: 'search-plugin'));

    transaction.commit();
    await diagnostics.close();

    expect(diagnostics.journal.isClosed, isTrue);
    expect(diagnostics.journal.add(_event('late')), isFalse);
    expect(diagnostics.rejectedEventCount, 1);
  });
}

CompositionLifecycleEvent _event(String id) => CompositionLifecycleEvent(
      correlationId: id,
      operation: CompositionLifecycleOperation.prepare,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.now().toUtc(),
      nodeIds: const [],
      ownerIds: const [],
    );

class _Lifecycle implements CompositionLifecycle {
  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {}

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {}

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}

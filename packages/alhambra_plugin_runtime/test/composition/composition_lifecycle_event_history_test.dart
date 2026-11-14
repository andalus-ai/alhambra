import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('retains lifecycle events in order with correlation IDs', () {
    final runtime = DefaultCompositionRuntime();
    final transaction = runtime.beginTransaction(
      correlationId: 'install-editor',
      lifecycle: _Lifecycle(),
    )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));
    expect(transaction.commit(), isA<CompositionSuccess>());

    final events = runtime.lifecycleEvents;
    expect(
      events.map((event) => event.operation),
      containsAllInOrder([
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.prepare,
        CompositionLifecycleOperation.activate,
        CompositionLifecycleOperation.activate,
      ]),
    );
    expect(events.every((event) => event.correlationId == 'install-editor'), isTrue);
    expect(events.map((event) => event.status), contains(CompositionLifecycleStatus.succeeded));
  });

  test('event history is immutable and bounded', () {
    final runtime = DefaultCompositionRuntime(maxLifecycleEvents: 3);
    final transaction = runtime.beginTransaction(lifecycle: _Lifecycle())
      ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));
    transaction.commit();

    expect(runtime.lifecycleEvents, hasLength(3));
    expect(
      () => runtime.lifecycleEvents.clear(),
      throwsUnsupportedError,
    );
  });

  test('runtime records deactivation failure and compensation', () {
    final runtime = DefaultCompositionRuntime();
    final lifecycle = _Lifecycle(failDeactivate: true);
    final transaction = runtime.beginTransaction(lifecycle: lifecycle)
      ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));
    transaction.commit();

    expect(() => runtime.deactivateOwner('editor'), throwsA(isA<StateError>()));
    final events = runtime.lifecycleEvents;
    expect(
      events.any((event) =>
          event.operation == CompositionLifecycleOperation.deactivate &&
          event.status == CompositionLifecycleStatus.failed),
      isTrue,
    );
    expect(
      events.any((event) =>
          event.operation == CompositionLifecycleOperation.compensate &&
          event.status == CompositionLifecycleStatus.succeeded),
      isTrue,
    );
    expect(events.last.correlationId, startsWith('composition-deactivation-'));
  });

  test('event sink failure does not interrupt lifecycle execution', () {
    final runtime = DefaultCompositionRuntime(
      onLifecycleEvent: (_) => throw StateError('telemetry unavailable'),
    );
    final transaction = runtime.beginTransaction(
      lifecycle: _Lifecycle(),
    )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

    expect(transaction.commit(), isA<CompositionSuccess>());
    expect(runtime.graph.nodes.keys, contains('command:save'));
    expect(runtime.lifecycleEvents, isNotEmpty);
  });
}

class _Lifecycle implements CompositionLifecycle {
  final bool failDeactivate;
  _Lifecycle({this.failDeactivate = false});

  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {}

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    if (failDeactivate) throw StateError('deactivation failed');
  }

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}

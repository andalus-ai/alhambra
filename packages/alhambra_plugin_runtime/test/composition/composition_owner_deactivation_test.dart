import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('owner deactivation emits correlated lifecycle events', () {
    final events = <CompositionLifecycleEvent>[];
    final runtime = DefaultCompositionRuntime(onLifecycleEvent: events.add);
    final lifecycle = _Lifecycle();
    final transaction = runtime.beginTransaction(
      lifecycle: lifecycle,
      correlationId: 'install-editor',
    )..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

    expect(transaction.commit(), isA<CompositionSuccess>());
    events.clear();

    runtime.deactivateOwner('editor');

    expect(runtime.graph.nodes, isEmpty);
    expect(lifecycle.deactivated, 1);
    expect(events.map((event) => event.operation), [
      CompositionLifecycleOperation.deactivate,
      CompositionLifecycleOperation.deactivate,
    ]);
    expect(events.map((event) => event.status), [
      CompositionLifecycleStatus.started,
      CompositionLifecycleStatus.succeeded,
    ]);
    expect(events.every((event) => event.correlationId.startsWith(
      'composition-deactivation-',
    )), isTrue);
    expect(events.every((event) => event.nodeIds.single == 'command:save'), isTrue);
    expect(events.every((event) => event.ownerIds.single == 'editor'), isTrue);
  });

  test('failed owner deactivation reports failure and restores graph', () {
    final events = <CompositionLifecycleEvent>[];
    final runtime = DefaultCompositionRuntime(onLifecycleEvent: events.add);
    final lifecycle = _Lifecycle(failDeactivate: true);
    final transaction = runtime.beginTransaction(lifecycle: lifecycle)
      ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

    transaction.commit();
    final before = runtime.graph.nodes;

    expect(runtime.deactivateOwner, throwsA(isA<StateError>()));
    expect(runtime.graph.nodes, before);
    expect(events.any((event) =>
      event.operation == CompositionLifecycleOperation.deactivate &&
      event.status == CompositionLifecycleStatus.failed), isTrue);
    expect(events.any((event) =>
      event.operation == CompositionLifecycleOperation.compensate &&
      event.status == CompositionLifecycleStatus.started), isTrue);
  });
}

class _Lifecycle implements CompositionLifecycle {
  final bool failDeactivate;
  int deactivated = 0;

  _Lifecycle({this.failDeactivate = false});

  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {}

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    deactivated++;
    if (failDeactivate) throw StateError('deactivation failed');
  }

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}

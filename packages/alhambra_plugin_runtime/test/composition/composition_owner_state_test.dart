import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('owner state transitions from active to inactive', () {
    final runtime = DefaultCompositionRuntime();
    _install(runtime, CommandNode(commandId: 'save', ownerId: 'editor'));

    expect(runtime.ownerState('editor'), CompositionOwnerState.active);
    expect(runtime.ownerStates['editor'], CompositionOwnerState.active);

    runtime.deactivateOwner('editor');

    expect(runtime.ownerState('editor'), CompositionOwnerState.inactive);
    expect(runtime.graph.nodes, isEmpty);
  });

  test('owner state becomes failed and registration is blocked after failure', () {
    final runtime = DefaultCompositionRuntime();
    _install(
      runtime,
      CommandNode(commandId: 'save', ownerId: 'editor'),
      lifecycle: _Lifecycle(failDeactivate: true),
    );

    expect(() => runtime.deactivateOwner('editor'), throwsA(isA<StateError>()));
    expect(runtime.ownerState('editor'), CompositionOwnerState.failed);
    expect(runtime.graph.nodes.keys, contains('command:save'));

    final retry = runtime.beginTransaction()
      ..stage(CommandNode(commandId: 'another', ownerId: 'editor'));
    expect(
      retry.commit,
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('editor'),
      )),
    );
    expect(retry.isRolledBack, isTrue);
    expect(runtime.graph.nodes.keys, isNot(contains('command:another')));
  });

  test('registration for a deactivating owner is rejected before publication', () {
    final runtime = DefaultCompositionRuntime();
    final lifecycle = _RegisterDuringDeactivation(runtime);
    _install(
      runtime,
      CommandNode(commandId: 'save', ownerId: 'editor'),
      lifecycle: lifecycle,
    );

    runtime.deactivateOwner('editor');

    expect(lifecycle.registrationRejected, isTrue);
    expect(runtime.ownerState('editor'), CompositionOwnerState.inactive);
    expect(runtime.graph.nodes, isEmpty);
  });

  test('inactive owner can be installed again and returns to active', () {
    final runtime = DefaultCompositionRuntime();
    _install(runtime, CommandNode(commandId: 'first', ownerId: 'editor'));
    runtime.deactivateOwner('editor');

    _install(runtime, CommandNode(commandId: 'second', ownerId: 'editor'));

    expect(runtime.ownerState('editor'), CompositionOwnerState.active);
    expect(runtime.graph.nodes.keys, contains('command:second'));
  });

  test('owner state snapshot cannot be mutated by callers', () {
    final runtime = DefaultCompositionRuntime();
    _install(runtime, CommandNode(commandId: 'save', ownerId: 'editor'));

    expect(
      () => runtime.ownerStates['editor'] = CompositionOwnerState.failed,
      throwsUnsupportedError,
    );
    expect(runtime.ownerState('editor'), CompositionOwnerState.active);
  });
}

void _install(
  DefaultCompositionRuntime runtime,
  CompositionNode node, {
  CompositionLifecycle? lifecycle,
}) {
  final transaction = runtime.beginTransaction(lifecycle: lifecycle)..stage(node);
  expect(transaction.commit(), isA<CompositionSuccess>());
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

class _RegisterDuringDeactivation extends _Lifecycle {
  final DefaultCompositionRuntime runtime;
  bool registrationRejected = false;

  _RegisterDuringDeactivation(this.runtime);

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    final transaction = runtime.beginTransaction()
      ..stage(CommandNode(commandId: 'late', ownerId: 'editor'));
    try {
      transaction.commit();
    } on StateError {
      registrationRejected = true;
    }
  }
}

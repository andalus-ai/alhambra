import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('failed owner recovers through prepare and activate', () {
    final lifecycle = _RecoveryLifecycle(failDeactivate: true);
    final runtime = DefaultCompositionRuntime();
    _install(runtime, lifecycle);

    expect(() => runtime.deactivateOwner('editor'), throwsA(isA<StateError>()));
    expect(runtime.ownerState('editor'), CompositionOwnerState.failed);
    expect(runtime.graph.nodes.keys, contains('command:save'));

    lifecycle
      ..failDeactivate = false
      ..resetRecoveryCalls();
    runtime.recoverOwner('editor');

    expect(runtime.ownerState('editor'), CompositionOwnerState.active);
    expect(runtime.graph.nodes.keys, contains('command:save'));
    expect(lifecycle.prepareCalls, 2);
    expect(lifecycle.activateCalls, 2);
  });

  test('failed recovery preserves failed state and graph', () {
    final lifecycle = _RecoveryLifecycle(failDeactivate: true);
    final runtime = DefaultCompositionRuntime();
    _install(runtime, lifecycle);
    expect(() => runtime.deactivateOwner('editor'), throwsA(isA<StateError>()));

    lifecycle
      ..failDeactivate = false
      ..failRecoveryActivation = true;
    expect(() => runtime.recoverOwner('editor'), throwsA(isA<StateError>()));

    expect(runtime.ownerState('editor'), CompositionOwnerState.failed);
    expect(runtime.graph.nodes.keys, contains('command:save'));
    expect(lifecycle.compensateCalls, greaterThanOrEqualTo(2));
  });

  test('recovery is rejected for owners not in failed state', () {
    final runtime = DefaultCompositionRuntime();
    _install(runtime, _RecoveryLifecycle());

    expect(() => runtime.recoverOwner('editor'), throwsA(isA<StateError>()));
    expect(runtime.ownerState('editor'), CompositionOwnerState.active);
  });

  test('failed owner without lifecycle cannot be silently reset', () {
    final runtime = DefaultCompositionRuntime(
      onOwnerDeactivated: (_) => throw StateError('external shutdown failed'),
    );
    final transaction = runtime.beginTransaction()
      ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));
    expect(transaction.commit(), isA<CompositionSuccess>());
    expect(() => runtime.deactivateOwner('editor'), throwsA(isA<StateError>()));

    expect(runtime.ownerState('editor'), CompositionOwnerState.failed);
    expect(() => runtime.recoverOwner('editor'), throwsA(isA<StateError>()));
    expect(runtime.ownerState('editor'), CompositionOwnerState.failed);
  });
}

void _install(DefaultCompositionRuntime runtime, _RecoveryLifecycle lifecycle) {
  final transaction = runtime.beginTransaction(lifecycle: lifecycle)
    ..stage(CommandNode(commandId: 'save', ownerId: 'editor'));
  expect(transaction.commit(), isA<CompositionSuccess>());
}

class _RecoveryLifecycle implements CompositionLifecycle {
  bool failDeactivate;
  bool failRecoveryActivation;
  int prepareCalls = 0;
  int activateCalls = 0;
  int compensateCalls = 0;

  _RecoveryLifecycle({
    this.failDeactivate = false,
    this.failRecoveryActivation = false,
  });

  void resetRecoveryCalls() {
    prepareCalls = 0;
    activateCalls = 0;
  }

  @override
  void prepare(List<CompositionNode> orderedNodes) {
    prepareCalls++;
  }

  @override
  void activate(List<CompositionNode> orderedNodes) {
    activateCalls++;
    if (failRecoveryActivation && activateCalls > 1) {
      throw StateError('recovery activation failed');
    }
  }

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    if (failDeactivate) throw StateError('deactivation failed');
  }

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {
    compensateCalls++;
  }
}

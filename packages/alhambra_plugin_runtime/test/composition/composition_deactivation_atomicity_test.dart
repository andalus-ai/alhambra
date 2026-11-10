import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('reentrant owner deactivation is rejected and outer graph is restored', () {
    late DefaultCompositionRuntime runtime;
    final lifecycle = _ReentrantLifecycle(() {
      runtime.deactivateOwner('nested');
    });
    runtime = DefaultCompositionRuntime();
    _install(runtime, CommandNode(commandId: 'outer', ownerId: 'outer'), lifecycle);
    _install(runtime, CommandNode(commandId: 'nested', ownerId: 'nested'), _Lifecycle());

    expect(
      () => runtime.deactivateOwner('outer'),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('already in progress'),
      )),
    );
    expect(runtime.graph.nodes.keys.toSet(), {
      'command:outer',
      'command:nested',
    });
  });

  test('only successfully deactivated owners are compensated', () {
    final runtime = DefaultCompositionRuntime();
    final consumerLifecycle = _Lifecycle();
    final providerLifecycle = _Lifecycle(failDeactivate: true);

    _install(
      runtime,
      ServiceNode(serviceId: 'provider', ownerId: 'provider'),
      providerLifecycle,
    );
    _install(
      runtime,
      ViewNode(
        viewId: 'consumer',
        ownerId: 'consumer',
        dependencies: {const CompositionDependency('service:provider')},
      ),
      consumerLifecycle,
    );

    expect(
      () => runtime.deactivateOwner('provider', DeactivationStrategy.cascade),
      throwsA(isA<StateError>()),
    );

    expect(consumerLifecycle.compensated, 1);
    expect(providerLifecycle.compensated, 0);
    expect(runtime.graph.nodes.keys.toSet(), {
      'service:provider',
      'view:consumer',
    });
  });

  test('deactivation guard is released after failure', () {
    final runtime = DefaultCompositionRuntime();
    final lifecycle = _Lifecycle(failDeactivate: true);
    _install(runtime, CommandNode(commandId: 'retry', ownerId: 'retry'), lifecycle);

    expect(() => runtime.deactivateOwner('retry'), throwsA(isA<StateError>()));
    lifecycle.failDeactivate = false;
    expect(() => runtime.deactivateOwner('retry'), returnsNormally);
    expect(runtime.graph.nodes, isEmpty);
  });
}

void _install(
  DefaultCompositionRuntime runtime,
  CompositionNode node,
  CompositionLifecycle lifecycle,
) {
  final transaction = runtime.beginTransaction(lifecycle: lifecycle)..stage(node);
  expect(transaction.commit(), isA<CompositionSuccess>());
}

class _Lifecycle implements CompositionLifecycle {
  bool failDeactivate;
  int compensated = 0;

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
  ) {
    compensated++;
  }
}

class _ReentrantLifecycle extends _Lifecycle {
  final void Function() nestedDeactivation;

  _ReentrantLifecycle(this.nestedDeactivation);

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    nestedDeactivation();
  }
}

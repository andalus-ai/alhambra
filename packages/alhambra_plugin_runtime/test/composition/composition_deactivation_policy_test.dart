import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('owner deactivation dependency policies', () {
    test('reject blocks required and optional external dependents atomically', () {
      final runtime = DefaultCompositionRuntime();
      _install(runtime, [
        ServiceNode(serviceId: 'provider', ownerId: 'provider'),
        ViewNode(
          viewId: 'required-consumer',
          ownerId: 'consumer-a',
          dependencies: {const CompositionDependency('service:provider')},
        ),
        ViewNode(
          viewId: 'optional-consumer',
          ownerId: 'consumer-b',
          dependencies: {
            const CompositionDependency('service:provider', required: false),
          },
        ),
      ]);
      final before = Map<String, CompositionNode>.from(runtime.graph.nodes);

      expect(
        () => runtime.deactivateOwner('provider', DeactivationStrategy.reject),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('view:optional-consumer'),
        )),
      );

      _expectSameGraph(runtime, before);
    });

    test('cascade removes transitive dependents consumer before provider', () {
      final runtime = DefaultCompositionRuntime();
      final lifecycle = _RecordingLifecycle();
      _install(runtime, [
        ServiceNode(serviceId: 'provider', ownerId: 'provider'),
        CommandNode(
          commandId: 'middle',
          ownerId: 'middle',
          dependencies: {const CompositionDependency('service:provider')},
        ),
        ViewNode(
          viewId: 'leaf',
          ownerId: 'leaf',
          dependencies: {const CompositionDependency('command:middle')},
        ),
        ViewNode(viewId: 'unrelated', ownerId: 'other'),
      ], lifecycle: lifecycle);

      runtime.deactivateOwner('provider', DeactivationStrategy.cascade);

      expect(runtime.graph.nodes.keys, contains('view:unrelated'));
      expect(runtime.graph.nodes.keys, isNot(contains('service:provider')));
      expect(runtime.graph.nodes.keys, isNot(contains('command:middle')));
      expect(runtime.graph.nodes.keys, isNot(contains('view:leaf')));
      expect(lifecycle.deactivatedOwners, ['leaf', 'middle', 'provider']);
      expect(lifecycle.deactivatedNodeIds, [
        ['view:leaf'],
        ['command:middle'],
        ['service:provider'],
      ]);
    });

    test('degrade retains optional-only consumers but removes required chains', () {
      final runtime = DefaultCompositionRuntime();
      final lifecycle = _RecordingLifecycle();
      _install(runtime, [
        ServiceNode(serviceId: 'provider', ownerId: 'provider'),
        CommandNode(
          commandId: 'required-middle',
          ownerId: 'required-middle',
          dependencies: {const CompositionDependency('service:provider')},
        ),
        ViewNode(
          viewId: 'required-leaf',
          ownerId: 'required-leaf',
          dependencies: {
            const CompositionDependency('command:required-middle'),
          },
        ),
        ViewNode(
          viewId: 'optional',
          ownerId: 'optional',
          dependencies: {
            const CompositionDependency('service:provider', required: false),
          },
        ),
        ViewNode(viewId: 'unrelated', ownerId: 'other'),
      ], lifecycle: lifecycle);

      runtime.deactivateOwner('provider', DeactivationStrategy.degrade);

      expect(runtime.graph.nodes.keys.toSet(), {
        'view:optional',
        'view:unrelated',
      });
      expect(lifecycle.deactivatedOwners, [
        'required-leaf',
        'required-middle',
        'provider',
      ]);
    });

    test('deactivation order is deterministic when branches share a provider', () {
      final runtime = DefaultCompositionRuntime();
      final lifecycle = _RecordingLifecycle();
      _install(runtime, [
        ServiceNode(serviceId: 'provider', ownerId: 'provider'),
        ViewNode(
          viewId: 'z-consumer',
          ownerId: 'z-owner',
          dependencies: {const CompositionDependency('service:provider')},
        ),
        ViewNode(
          viewId: 'a-consumer',
          ownerId: 'a-owner',
          dependencies: {const CompositionDependency('service:provider')},
        ),
      ], lifecycle: lifecycle);

      runtime.deactivateOwner('provider', DeactivationStrategy.cascade);

      expect(lifecycle.deactivatedNodeIds, [
        ['view:a-consumer', 'view:z-consumer'],
        ['service:provider'],
      ]);
    });
  });
}

void _install(
  DefaultCompositionRuntime runtime,
  List<CompositionNode> nodes, {
  _RecordingLifecycle? lifecycle,
}) {
  final transaction = runtime.beginTransaction(lifecycle: lifecycle);
  for (final node in nodes) {
    transaction.stage(node);
  }
  expect(transaction.commit(), isA<CompositionSuccess>());
}

void _expectSameGraph(
  DefaultCompositionRuntime runtime,
  Map<String, CompositionNode> before,
) {
  expect(runtime.graph.nodes.keys.toSet(), before.keys.toSet());
  for (final entry in before.entries) {
    expect(runtime.graph.nodes[entry.key], same(entry.value));
  }
}

class _RecordingLifecycle implements CompositionLifecycle {
  final deactivatedOwners = <String>[];
  final deactivatedNodeIds = <List<String>>[];

  @override
  void prepare(List<CompositionNode> orderedNodes) {}

  @override
  void activate(List<CompositionNode> orderedNodes) {}

  @override
  void deactivate(List<CompositionNode> reverseOrderedNodes) {
    deactivatedOwners.add(reverseOrderedNodes.first.ownerId);
    deactivatedNodeIds.add(reverseOrderedNodes.map((node) => node.id).toList());
  }

  @override
  void compensate(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {}
}

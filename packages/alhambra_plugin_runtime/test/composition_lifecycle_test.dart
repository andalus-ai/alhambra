import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  ServiceNode service(String id, {Set<CompositionDependency> dependencies = const {}}) =>
      ServiceNode(serviceId: id, ownerId: 'test.owner', dependencies: dependencies);

  CompositionPlan planWithDependencies() {
    final graph = CompositionGraph()
      ..add(service('provider'))
      ..add(service('consumer', dependencies: {
        const CompositionDependency('service:provider'),
      }));
    return CompositionPlan.fromGraph(graph);
  }

  group('CompositionLifecycleCoordinator', () {
    test('activates dependency-first and deactivates in reverse order', () async {
      final events = <String>[];
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (node) => events.add('activate:${node.id}'),
        deactivateNode: (node) => events.add('deactivate:${node.id}'),
      );
      final plan = planWithDependencies();

      final activation = await coordinator.activate(plan);
      expect(activation.succeeded, isTrue);
      expect(activation.activatedNodeIds, ['service:provider', 'service:consumer']);
      expect(events, ['activate:service:provider', 'activate:service:consumer']);
      expect(coordinator.stateOf('service:provider'), CompositionNodeState.active);

      final deactivation = await coordinator.deactivate(plan);
      expect(deactivation.succeeded, isTrue);
      expect(deactivation.deactivatedNodeIds, ['service:consumer', 'service:provider']);
      expect(events.skip(2), ['deactivate:service:consumer', 'deactivate:service:provider']);
      expect(coordinator.stateOf('service:consumer'), CompositionNodeState.inactive);
    });

    test('compensates already activated nodes in reverse order after failure', () async {
      final events = <String>[];
      final plan = planWithDependencies();
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (node) {
          events.add('activate:${node.id}');
          if (node.id == 'service:consumer') throw StateError('consumer failed');
        },
        deactivateNode: (node) => events.add('deactivate:${node.id}'),
      );

      final result = await coordinator.activate(plan);
      expect(result.succeeded, isFalse);
      expect(result.failedNodeId, 'service:consumer');
      expect(result.activationError, isA<StateError>());
      expect(result.compensationErrors, isEmpty);
      expect(events, [
        'activate:service:provider',
        'activate:service:consumer',
        'deactivate:service:provider',
      ]);
      expect(coordinator.stateOf('service:provider'), CompositionNodeState.inactive);
      expect(coordinator.stateOf('service:consumer'), CompositionNodeState.failed);
    });

    test('retries activation according to policy', () async {
      var attempts = 0;
      final graph = CompositionGraph()..add(service('only'));
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (_) {
          attempts++;
          if (attempts == 1) throw StateError('transient');
        },
        deactivateNode: (_) {},
        retryPolicy: const CompositionRetryPolicy(maxAttempts: 2),
      );

      final result = await coordinator.activate(CompositionPlan.fromGraph(graph));
      expect(result.succeeded, isTrue);
      expect(attempts, 2);
    });

    test('records compensation errors without hiding activation failure', () async {
      final plan = planWithDependencies();
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (node) {
          if (node.id == 'service:consumer') throw StateError('activation');
        },
        deactivateNode: (_) => throw StateError('compensation'),
      );

      final result = await coordinator.activate(plan);
      expect(result.succeeded, isFalse);
      expect(result.activationError, isA<StateError>());
      expect(result.compensationErrors, hasLength(1));
      expect(result.compensationErrors.single.nodeId, 'service:provider');
      expect(coordinator.stateOf('service:provider'), CompositionNodeState.failed);
    });

    test('deactivation continues after a node callback fails', () async {
      final plan = planWithDependencies();
      final events = <String>[];
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (_) {},
        deactivateNode: (node) {
          events.add(node.id);
          if (node.id == 'service:consumer') throw StateError('cannot stop consumer');
        },
      );
      await coordinator.activate(plan);

      final result = await coordinator.deactivate(plan);
      expect(result.succeeded, isFalse);
      expect(result.errors.single.nodeId, 'service:consumer');
      expect(events, ['service:consumer', 'service:provider']);
      expect(coordinator.stateOf('service:consumer'), CompositionNodeState.failed);
      expect(coordinator.stateOf('service:provider'), CompositionNodeState.inactive);
    });

    test('reconcile removes stale state without invoking callbacks', () async {
      var calls = 0;
      final oldPlan = planWithDependencies();
      final coordinator = CompositionLifecycleCoordinator(
        activateNode: (_) => calls++,
        deactivateNode: (_) => calls++,
      );
      await coordinator.activate(oldPlan);
      final newGraph = CompositionGraph()..add(service('replacement'));

      coordinator.reconcile(CompositionPlan.fromGraph(newGraph));
      expect(coordinator.states.keys, ['service:replacement']);
      expect(coordinator.stateOf('service:replacement'), CompositionNodeState.declared);
      expect(calls, 2);
    });
  });
}

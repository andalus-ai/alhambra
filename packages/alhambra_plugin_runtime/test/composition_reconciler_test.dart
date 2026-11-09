import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  ServiceNode service(
    String id, {
    String owner = 'owner',
    Set<CompositionDependency> dependencies = const {},
  }) =>
      ServiceNode(serviceId: id, ownerId: owner, dependencies: dependencies);

  CompositionPlan plan(Iterable<CompositionNode> nodes) {
    final graph = CompositionGraph()..addAll(nodes);
    return CompositionPlan.fromGraph(graph);
  }

  group('CompositionPlanDiff', () {
    test('classifies additions, removals, replacements and unchanged nodes', () {
      final current = plan([
        service('stable'),
        service('remove-me'),
        service('replace-me', owner: 'old.owner'),
      ]);
      final desired = plan([
        service('stable'),
        service('added'),
        service('replace-me', owner: 'new.owner'),
      ]);

      final diff = CompositionPlanDiff.between(current, desired);
      expect(diff.unchanged.map((node) => node.id), ['service:stable']);
      expect(diff.added.map((node) => node.id), ['service:added']);
      expect(diff.removed.map((node) => node.id), ['service:remove-me']);
      expect(diff.replaced.map((node) => node.id), ['service:replace-me']);
      expect(diff.isEmpty, isFalse);
    });

    test('dependency changes make a node a replacement', () {
      final current = plan([
        service('provider'),
        service('consumer'),
      ]);
      final desired = plan([
        service('provider'),
        service('consumer', dependencies: {
          const CompositionDependency('service:provider'),
        }),
      ]);

      final diff = CompositionPlanDiff.between(current, desired);
      expect(diff.replaced.map((node) => node.id), ['service:consumer']);
      expect(diff.unchanged.map((node) => node.id), ['service:provider']);
    });

    test('identical plans produce an empty diff', () {
      final current = plan([service('one')]);
      final desired = plan([service('one')]);
      expect(CompositionPlanDiff.between(current, desired).isEmpty, isTrue);
    });
  });

  group('CompositionReconciler', () {
    test('preserves unchanged nodes and orders stop/start callbacks', () async {
      final current = plan([
        service('provider'),
        service('old-consumer', dependencies: {
          const CompositionDependency('service:provider'),
        }),
      ]);
      final desired = plan([
        service('provider'),
        service('new-consumer', dependencies: {
          const CompositionDependency('service:provider'),
        }),
      ]);
      final events = <String>[];
      final reconciler = CompositionReconciler(
        deactivateNode: (node) => events.add('stop:${node.id}'),
        activateNode: (node) => events.add('start:${node.id}'),
      );

      final result = await reconciler.reconcile(current: current, desired: desired);
      expect(result.succeeded, isTrue);
      expect(result.deactivatedNodeIds, ['service:old-consumer']);
      expect(result.activatedNodeIds, ['service:new-consumer']);
      expect(events, [
        'stop:service:old-consumer',
        'start:service:new-consumer',
      ]);
    });

    test('restores the old node when replacement activation fails', () async {
      final current = plan([service('replace', owner: 'old.owner')]);
      final desired = plan([service('replace', owner: 'new.owner')]);
      final events = <String>[];
      final reconciler = CompositionReconciler(
        deactivateNode: (node) => events.add('stop:${node.ownerId}'),
        activateNode: (node) {
          events.add('start:${node.ownerId}');
          if (node.ownerId == 'new.owner') throw StateError('new version failed');
        },
      );

      final result = await reconciler.reconcile(current: current, desired: desired);
      expect(result.succeeded, isFalse);
      expect(result.failedNodeId, 'service:replace');
      expect(result.cause, isA<StateError>());
      expect(result.rollbackErrors, isEmpty);
      expect(events, [
        'stop:old.owner',
        'start:new.owner',
        'start:old.owner',
      ]);
    });

    test('reports rollback failures separately from the primary failure', () async {
      final current = plan([service('replace', owner: 'old.owner')]);
      final desired = plan([service('replace', owner: 'new.owner')]);
      final reconciler = CompositionReconciler(
        deactivateNode: (_) {},
        activateNode: (node) {
          if (node.ownerId == 'new.owner') throw StateError('new failed');
          throw StateError('restore failed');
        },
      );

      final result = await reconciler.reconcile(current: current, desired: desired);
      expect(result.succeeded, isFalse);
      expect(result.cause, isA<StateError>());
      expect(result.rollbackErrors, hasLength(1));
      expect(result.rollbackErrors.single.nodeId, 'service:replace');
    });

    test('does not invoke callbacks for identical plans', () async {
      var calls = 0;
      final current = plan([service('one')]);
      final reconciler = CompositionReconciler(
        deactivateNode: (_) => calls++,
        activateNode: (_) => calls++,
      );

      final result = await reconciler.reconcile(current: current, desired: plan([service('one')]));
      expect(result.succeeded, isTrue);
      expect(result.diff.isEmpty, isTrue);
      expect(calls, 0);
    });
  });
}

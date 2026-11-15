import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Plugin implements AlhambraPlugin {
  _Plugin(this.id);
  final String id;
  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');
  @override
  Future<void> activate(PluginContext context) async {}
  @override
  Future<void> deactivate(PluginContext context) async {}
}

PluginLifecycleCheckpoint _checkpoint(
  String id, {
  String? operationId,
  int sequence = 3,
  List<String> dependencies = const [],
}) {
  final now = DateTime.utc(2026, 11, 14);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: operationId ?? 'old-$id',
    operation: PluginLifecycleOperation.startup,
    state: PluginLifecycleCheckpointState.starting,
    sequence: sequence,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
    dependencyIds: dependencies,
  );
}

PluginLifecycleRecoveryBatchRequest _request() => PluginLifecycleRecoveryBatchRequest(
  pluginIds: ['app', 'core'],
  action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
  compiledPlugins: {'core': _Plugin('core'), 'app': _Plugin('app')},
  operationIdFactory: (id) => 'reserved-$id',
);

void main() {
  group('PluginLifecycleRecoveryBatchPlanner.validatePlan', () {
    test('accepts an unchanged plan and preserves its reserved operation IDs', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('core'));
      await store.write(_checkpoint('app', dependencies: ['core']));
      final manager = PluginManager();
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: manager);
      final plan = await planner.planBatch(_request());

      final validation = await planner.validatePlan(plan: plan, request: _request());

      expect(validation.isCurrent, isTrue);
      expect(validation.blockers, isEmpty);
      expect(validation.currentPlan!.steps.map((s) => s.executionOperationId),
          ['reserved-core', 'reserved-app']);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('core'))!.sequence, 3);
    });

    test('detects checkpoint sequence and dependency snapshot changes', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('core'));
      await store.write(_checkpoint('app', dependencies: ['core']));
      final planner = PluginLifecycleRecoveryBatchPlanner(
        store: store,
        manager: PluginManager(),
      );
      final plan = await planner.planBatch(_request());

      await store.write(_checkpoint('core', sequence: 4));
      final validation = await planner.validatePlan(plan: plan, request: _request());

      expect(validation.isCurrent, isFalse);
      expect(validation.blockers, contains(
        'Recovery snapshot for "core" changed since the plan was reviewed.',
      ));
    });

    test('rejects a plan for a different action without reading it as current', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('core'));
      await store.write(_checkpoint('app', dependencies: ['core']));
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: PluginManager());
      final plan = await planner.planBatch(_request());
      final differentRequest = PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['app', 'core'],
        action: PluginLifecycleRecoveryExecutionAction.compensateShutdown,
        operationIdFactory: (id) => 'reserved-$id',
      );

      final validation = await planner.validatePlan(
        plan: plan,
        request: differentRequest,
      );

      expect(validation.isCurrent, isFalse);
      expect(validation.currentPlan, isNull);
      expect(validation.blockers.single, contains('action differs'));
    });

    test('does not mutate manager or checkpoints when a plan becomes blocked', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('core'));
      await store.write(_checkpoint('app', dependencies: ['core']));
      final manager = PluginManager();
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: manager);
      final plan = await planner.planBatch(_request());

      await store.write(PluginLifecycleCheckpoint(
        pluginId: 'app',
        operationId: 'changed-app',
        operation: PluginLifecycleOperation.startup,
        state: PluginLifecycleCheckpointState.active,
        sequence: 4,
        attempt: 1,
        createdAt: DateTime.utc(2026, 11, 14),
        updatedAt: DateTime.utc(2026, 11, 14),
        dependencyIds: ['core'],
      ));
      final validation = await planner.validatePlan(plan: plan, request: _request());

      expect(validation.isCurrent, isFalse);
      expect(validation.blockers, isNotEmpty);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('app'))!.state, PluginLifecycleCheckpointState.active);
    });
  });
}

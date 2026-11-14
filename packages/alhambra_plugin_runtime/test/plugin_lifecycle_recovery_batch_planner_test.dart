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
  List<String> dependencies = const [],
  PluginLifecycleOperation operation = PluginLifecycleOperation.startup,
  PluginLifecycleCheckpointState state = PluginLifecycleCheckpointState.starting,
}) {
  final now = DateTime.utc(2026, 11, 14);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: 'old-$id',
    operation: operation,
    state: state,
    sequence: 4,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
    dependencyIds: dependencies,
  );
}

void main() {
  group('PluginLifecycleRecoveryBatchPlanner', () {
    test('creates a dependency-first plan and a matching immutable job without mutation', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('app', dependencies: ['core']));
      await store.write(_checkpoint('core'));
      final manager = PluginManager();
      final core = _Plugin('core');
      final app = _Plugin('app');
      final planner = PluginLifecycleRecoveryBatchPlanner(
        store: store,
        manager: manager,
        clock: () => DateTime.utc(2026, 11, 14, 10),
      );

      final plan = await planner.planBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['app', 'core'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'core': core, 'app': app},
        operationIdFactory: (id) => 'reserved-$id',
      ));

      expect(plan.isExecutable, isTrue);
      expect(plan.isBlocked, isFalse);
      expect(plan.orderedPluginIds, ['core', 'app']);
      expect(plan.steps.map((step) => step.expectedCheckpointSequence), [4, 4]);
      expect(plan.steps.map((step) => step.executionOperationId), ['reserved-core', 'reserved-app']);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('core'))!.sequence, 4);
      expect((await store.read('app'))!.sequence, 4);

      final job = plan.toJob(
        jobId: 'job-1',
        idempotencyKey: 'idem-1',
        operationId: 'batch-op-1',
        initiatedBy: 'operator-1',
      );
      expect(job.status, PluginRecoveryJobStatus.planned);
      expect(job.orderedPluginIds, ['core', 'app']);
      expect(job.steps.map((step) => step.expectedCheckpointOperationId), ['old-core', 'old-app']);
      expect(job.steps.map((step) => step.expectedCheckpointSequence), [4, 4]);
      expect(job.steps.map((step) => step.executionOperationId), ['reserved-core', 'reserved-app']);
    });

    test('orders shutdown compensation dependent-first', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'core',
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
      ));
      await store.write(_checkpoint(
        'app',
        dependencies: ['core'],
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
      ));
      final manager = PluginManager();
      await manager.activate(_Plugin('core'));
      await manager.activate(_Plugin('app'));
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: manager);

      final plan = await planner.planBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['core', 'app'],
        action: PluginLifecycleRecoveryExecutionAction.compensateShutdown,
        operationIdFactory: (id) => 'shutdown-$id',
      ));

      expect(plan.isExecutable, isTrue);
      expect(plan.orderedPluginIds, ['app', 'core']);
      expect(manager.activePlugins.map((plugin) => plugin.metadata.id), ['core', 'app']);
    });

    test('returns blockers for missing dependencies and dependency cycles', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('a', dependencies: ['b']));
      await store.write(_checkpoint('b', dependencies: ['a']));
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: PluginManager());

      final plan = await planner.planBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['a', 'b'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'a': _Plugin('a'), 'b': _Plugin('b')},
        operationIdFactory: (id) => 'cycle-$id',
      ));

      expect(plan.isExecutable, isFalse);
      expect(plan.blockers, contains('Recovery batch dependency graph contains a cycle.'));
      expect(() => plan.toJob(
        jobId: 'job',
        idempotencyKey: 'idem',
        operationId: 'op',
      ), throwsStateError);
    });

    test('blocks duplicate operation IDs before producing steps', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('a'));
      await store.write(_checkpoint('b'));
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: PluginManager());

      final plan = await planner.planBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['a', 'b'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'a': _Plugin('a'), 'b': _Plugin('b')},
        operationIdFactory: (_) => 'same-id',
      ));

      expect(plan.isBlocked, isTrue);
      expect(plan.steps, isEmpty);
      expect(plan.blockers, contains('Recovery operation IDs must be unique within a batch.'));
    });

    test('blocks stale or ineligible checkpoints without creating a job', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'already-active',
        state: PluginLifecycleCheckpointState.active,
      ));
      final planner = PluginLifecycleRecoveryBatchPlanner(store: store, manager: PluginManager());

      final plan = await planner.planBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['already-active'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'already-active': _Plugin('already-active')},
        operationIdFactory: (id) => 'new-$id',
      ));

      expect(plan.isBlocked, isTrue);
      expect(plan.blockers.single, contains('no incomplete startup checkpoint'));
    });
  });
}

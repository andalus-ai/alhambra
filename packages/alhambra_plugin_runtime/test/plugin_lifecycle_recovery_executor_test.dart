import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Plugin implements AlhambraPlugin {
  _Plugin(this.id);
  final String id;
  int activations = 0;
  int deactivations = 0;

  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');

  @override
  Future<void> activate(PluginContext context) async {
    activations++;
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    deactivations++;
  }
}

class _Executor implements PluginLifecycleRecoveryExecutor {
  _Executor(this.action);
  final Future<void> Function(PluginLifecycleRecoveryExecutionContext) action;

  @override
  Future<void> execute(PluginLifecycleRecoveryExecutionContext context) => action(context);
}

PluginLifecycleCheckpoint _checkpoint(
  String id, {
  PluginLifecycleOperation operation = PluginLifecycleOperation.startup,
  PluginLifecycleCheckpointState state = PluginLifecycleCheckpointState.starting,
  List<String> dependencies = const [],
}) {
  final now = DateTime.utc(2026, 11, 13);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: 'old-$id',
    operation: operation,
    state: state,
    sequence: 4,
    attempt: 2,
    createdAt: now,
    updatedAt: now,
    dependencyIds: dependencies,
  );
}

PluginLifecycleRecoveryExecutionRequest _request(
  String id,
  PluginLifecycleRecoveryExecutionAction action,
) => PluginLifecycleRecoveryExecutionRequest(
  pluginId: id,
  expectedOperationId: 'old-$id',
  expectedSequence: 4,
  newOperationId: 'recovery-$id',
  action: action,
);

void main() {
  group('PluginLifecycleRecoveryRunner', () {
    test('resumes startup through host executor and persists both boundaries', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin'));
      final manager = PluginManager();
      final plugin = _Plugin('plugin');
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          expect(context.checkpoint.state, PluginLifecycleCheckpointState.starting);
          await context.resumeStartup();
        }),
        clock: () => DateTime.utc(2026, 11, 13, 1),
      );

      final result = await runner.execute(
        _request('plugin', PluginLifecycleRecoveryExecutionAction.resumeStartup),
        compiledPlugin: plugin,
      );

      expect(result.state, PluginLifecycleCheckpointState.active);
      expect(result.operationId, 'recovery-plugin');
      expect(result.sequence, 6);
      expect(result.attempt, 3);
      expect(plugin.activations, 1);
      expect(manager.activePlugins.single.metadata.id, 'plugin');
    });

    test('requires active dependencies before resuming startup', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin', dependencies: ['dependency']));
      final manager = PluginManager();
      final plugin = _Plugin('plugin');
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) => context.resumeStartup()),
      );

      await expectLater(
        runner.execute(
          _request('plugin', PluginLifecycleRecoveryExecutionAction.resumeStartup),
          compiledPlugin: plugin,
        ),
        throwsStateError,
      );
      expect(plugin.activations, 0);
      expect((await store.read('plugin'))!.sequence, 4);
    });

    test('compensates interrupted shutdown through manager deactivation', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'plugin',
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
      ));
      final manager = PluginManager();
      final plugin = _Plugin('plugin');
      await manager.activate(plugin);
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          await context.compensateShutdown();
        }),
      );

      final result = await runner.execute(
        _request('plugin', PluginLifecycleRecoveryExecutionAction.compensateShutdown),
      );

      expect(result.state, PluginLifecycleCheckpointState.stopped);
      expect(result.sequence, 6);
      expect(plugin.deactivations, 1);
      expect(manager.activePlugins, isEmpty);
    });

    test('rejects shutdown compensation while an active dependent remains', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'dependency',
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
      ));
      await store.write(_checkpoint(
        'dependent',
        state: PluginLifecycleCheckpointState.active,
        dependencies: ['dependency'],
      ));
      final manager = PluginManager();
      await manager.activate(_Plugin('dependency'));
      await manager.activate(_Plugin('dependent'));
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) => context.compensateShutdown()),
      );

      await expectLater(
        runner.execute(
          _request('dependency', PluginLifecycleRecoveryExecutionAction.compensateShutdown),
        ),
        throwsStateError,
      );
      expect(manager.activePlugins.length, 2);
    });

    test('requires executor to invoke exactly one matching lifecycle action', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin'));
      final plugin = _Plugin('plugin');
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: PluginManager(),
        executor: _Executor((context) async {}),
      );

      await expectLater(
        runner.execute(
          _request('plugin', PluginLifecycleRecoveryExecutionAction.resumeStartup),
          compiledPlugin: plugin,
        ),
        throwsStateError,
      );
      final failed = await store.read('plugin');
      expect(failed!.state, PluginLifecycleCheckpointState.failed);
      expect(failed.sequence, 6);
      expect(plugin.activations, 0);
    });

    test('records failure when host executor fails after invoking lifecycle action', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin'));
      final manager = PluginManager();
      final plugin = _Plugin('plugin');
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          await context.resumeStartup();
          throw StateError('external verification failed');
        }),
        clock: () => DateTime.utc(2026, 11, 13, 1),
      );

      await expectLater(
        runner.execute(
          _request('plugin', PluginLifecycleRecoveryExecutionAction.resumeStartup),
          compiledPlugin: plugin,
        ),
        throwsStateError,
      );
      final failed = await store.read('plugin');
      expect(failed!.state, PluginLifecycleCheckpointState.failed);
      expect(failed.failureSummary, 'Host-controlled lifecycle recovery failed');
      expect(manager.activePlugins.single.metadata.id, 'plugin');
    });

    test('rejects stale request before invoking host executor', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin'));
      var invoked = false;
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: PluginManager(),
        executor: _Executor((context) async { invoked = true; }),
      );
      final stale = PluginLifecycleRecoveryExecutionRequest(
        pluginId: 'plugin',
        expectedOperationId: 'old-plugin',
        expectedSequence: 3,
        newOperationId: 'new-op',
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
      );

      await expectLater(
        runner.execute(stale, compiledPlugin: _Plugin('plugin')),
        throwsStateError,
      );
      expect(invoked, isFalse);
    });
  });
}

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
  _Executor(this.onExecute);
  final Future<void> Function(PluginLifecycleRecoveryExecutionContext) onExecute;

  @override
  Future<void> execute(PluginLifecycleRecoveryExecutionContext context) =>
      onExecute(context);
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
    sequence: 2,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
    dependencyIds: dependencies,
  );
}

void main() {
  group('PluginLifecycleRecoveryRunner.executeBatch', () {
    test('recovers startup in dependency-first order under one batch', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('app', dependencies: ['core']));
      await store.write(_checkpoint('core'));
      final manager = PluginManager();
      final core = _Plugin('core');
      final app = _Plugin('app');
      final order = <String>[];
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          order.add(context.plugin.metadata.id);
          await context.resumeStartup();
        }),
      );

      final report = await runner.executeBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['app', 'core'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'core': core, 'app': app},
        operationIdFactory: (id) => 'batch-$id',
      ));

      expect(report.succeeded, isTrue);
      expect(report.orderedPluginIds, ['core', 'app']);
      expect(report.completedPluginIds, ['core', 'app']);
      expect(report.skippedPluginIds, isEmpty);
      expect(order, ['core', 'app']);
      expect(manager.activePlugins.map((plugin) => plugin.metadata.id), ['core', 'app']);
      expect((await store.read('core'))!.state, PluginLifecycleCheckpointState.active);
      expect((await store.read('app'))!.state, PluginLifecycleCheckpointState.active);
    });

    test('compensates shutdown in dependent-first order', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'base',
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
      ));
      await store.write(_checkpoint(
        'app',
        operation: PluginLifecycleOperation.shutdown,
        state: PluginLifecycleCheckpointState.stopping,
        dependencies: ['base'],
      ));
      final manager = PluginManager();
      await manager.activate(_Plugin('base'));
      await manager.activate(_Plugin('app'));
      final order = <String>[];
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          order.add(context.plugin.metadata.id);
          await context.compensateShutdown();
        }),
      );

      final report = await runner.executeBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['base', 'app'],
        action: PluginLifecycleRecoveryExecutionAction.compensateShutdown,
        operationIdFactory: (id) => 'shutdown-recovery-$id',
      ));

      expect(report.succeeded, isTrue);
      expect(report.orderedPluginIds, ['app', 'base']);
      expect(order, ['app', 'base']);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('app'))!.state, PluginLifecycleCheckpointState.stopped);
      expect((await store.read('base'))!.state, PluginLifecycleCheckpointState.stopped);
    });

    test('stops after failure and reports untouched remainder', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('app', dependencies: ['core']));
      await store.write(_checkpoint('core'));
      final manager = PluginManager();
      final app = _Plugin('app');
      final core = _Plugin('core');
      final invoked = <String>[];
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: manager,
        executor: _Executor((context) async {
          invoked.add(context.plugin.metadata.id);
          throw StateError('host requires manual inspection');
        }),
      );

      final report = await runner.executeBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['app', 'core'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'core': core, 'app': app},
        operationIdFactory: (id) => 'failed-batch-$id',
      ));

      expect(report.succeeded, isFalse);
      expect(report.orderedPluginIds, ['core', 'app']);
      expect(report.failedPluginId, 'core');
      expect(report.completedPluginIds, isEmpty);
      expect(report.skippedPluginIds, ['app']);
      expect(invoked, ['core']);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('core'))!.state, PluginLifecycleCheckpointState.failed);
      expect((await store.read('app'))!.sequence, 2);
    });

    test('rejects dependency cycles before invoking executor', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('a', dependencies: ['b']));
      await store.write(_checkpoint('b', dependencies: ['a']));
      var invoked = false;
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: PluginManager(),
        executor: _Executor((context) async { invoked = true; }),
      );

      final report = await runner.executeBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['a', 'b'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'a': _Plugin('a'), 'b': _Plugin('b')},
        operationIdFactory: (id) => 'cycle-$id',
      ));

      expect(report.succeeded, isFalse);
      expect(report.error, isA<StateError>());
      expect(invoked, isFalse);
      expect((await store.read('a'))!.sequence, 2);
      expect((await store.read('b'))!.sequence, 2);
    });

    test('rejects duplicate operation IDs before executing any plugin', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('a'));
      await store.write(_checkpoint('b'));
      var invoked = false;
      final runner = PluginLifecycleRecoveryRunner(
        store: store,
        manager: PluginManager(),
        executor: _Executor((context) async { invoked = true; }),
      );

      final report = await runner.executeBatch(PluginLifecycleRecoveryBatchRequest(
        pluginIds: ['a', 'b'],
        action: PluginLifecycleRecoveryExecutionAction.resumeStartup,
        compiledPlugins: {'a': _Plugin('a'), 'b': _Plugin('b')},
        operationIdFactory: (_) => 'same-operation',
      ));

      expect(report.succeeded, isFalse);
      expect(report.error, isA<ArgumentError>());
      expect(invoked, isFalse);
      expect((await store.read('a'))!.sequence, 2);
      expect((await store.read('b'))!.sequence, 2);
    });
  });
}

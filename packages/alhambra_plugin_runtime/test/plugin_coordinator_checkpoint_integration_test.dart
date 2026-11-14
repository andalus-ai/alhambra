import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Plugin implements AlhambraPlugin {
  _Plugin(this.id, this.events, {this.failActivate = false, this.failDeactivate = false});
  final String id;
  final List<String> events;
  final bool failActivate;
  final bool failDeactivate;

  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');

  @override
  Future<void> activate(PluginContext context) async {
    events.add('activate:$id');
    if (failActivate) throw StateError('activation failed');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    events.add('deactivate:$id');
    if (failDeactivate) throw StateError('deactivation failed');
  }
}

DiscoveredPlugin _discovered(String id, {List<String> dependencies = const []}) =>
    DiscoveredPlugin(
      manifest: ExtensionManifest(
        id: id, name: id, version: '1.0.0', dependencies: dependencies,
      ),
      directory: Directory('/plugins/$id'),
    );

class _FailingStore implements PluginLifecycleCheckpointStore {
  final InMemoryPluginLifecycleCheckpointStore delegate =
      InMemoryPluginLifecycleCheckpointStore();

  @override
  Future<PluginLifecycleCheckpoint?> read(String pluginId) => delegate.read(pluginId);

  @override
  Future<List<PluginLifecycleCheckpoint>> readAll() => delegate.readAll();

  @override
  Future<void> delete(String pluginId) => delegate.delete(pluginId);

  @override
  Future<void> write(PluginLifecycleCheckpoint checkpoint) {
    if (checkpoint.state == PluginLifecycleCheckpointState.planned) {
      throw StateError('checkpoint storage unavailable');
    }
    return delegate.write(checkpoint);
  }
}

void main() {
  group('coordinator lifecycle checkpoints', () {
    test('startup records planned, starting and active in order', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      final events = <String>[];
      final report = await PluginStartupCoordinator(
        manager: PluginManager(),
        checkpointStore: store,
        operationIdFactory: () => 'batch-start-1',
      ).start(
        discoveredPlugins: [_discovered('editor')],
        compiledPlugins: {'editor': _Plugin('editor', events)},
      );

      expect(report.succeeded, isTrue);
      final checkpoint = await store.read('editor');
      expect(checkpoint!.operationId, 'batch-start-1');
      expect(checkpoint.operation, PluginLifecycleOperation.startup);
      expect(checkpoint.state, PluginLifecycleCheckpointState.active);
      expect(checkpoint.sequence, 2);
      expect(events, ['activate:editor']);
    });

    test('startup checkpoint preflight failure prevents activation', () async {
      final events = <String>[];
      final report = await PluginStartupCoordinator(
        manager: PluginManager(),
        checkpointStore: _FailingStore(),
      ).start(
        discoveredPlugins: [_discovered('editor')],
        compiledPlugins: {'editor': _Plugin('editor', events)},
      );

      expect(report.succeeded, isFalse);
      expect(report.error, isA<StateError>());
      expect(events, isEmpty);
    });

    test('startup failure records failed and reverse rollback terminal state', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      final events = <String>[];
      final manager = PluginManager();
      final report = await PluginStartupCoordinator(
        manager: manager,
        checkpointStore: store,
        operationIdFactory: () => 'batch-start-fail',
      ).start(
        discoveredPlugins: [
          _discovered('core'),
          _discovered('broken', dependencies: ['core']),
        ],
        compiledPlugins: {
          'core': _Plugin('core', events),
          'broken': _Plugin('broken', events, failActivate: true),
        },
      );

      expect(report.succeeded, isFalse);
      expect(report.rolledBackPluginIds, ['core']);
      expect((await store.read('broken'))!.state,
          PluginLifecycleCheckpointState.failed);
      expect((await store.read('core'))!.state,
          PluginLifecycleCheckpointState.stopped);
      expect(events, [
        'activate:core', 'activate:broken', 'deactivate:core',
      ]);
    });

    test('shutdown records planned, stopping and stopped', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('editor', events);
      await manager.activate(plugin);

      final report = await PluginShutdownCoordinator(
        manager: manager,
        checkpointStore: store,
        operationIdFactory: () => 'batch-stop-1',
      ).shutdown(discoveredPlugins: [_discovered('editor')]);

      expect(report.succeeded, isTrue);
      final checkpoint = await store.read('editor');
      expect(checkpoint!.operationId, 'batch-stop-1');
      expect(checkpoint.operation, PluginLifecycleOperation.shutdown);
      expect(checkpoint.state, PluginLifecycleCheckpointState.stopped);
      expect(checkpoint.sequence, 2);
      expect(events, ['activate:editor', 'deactivate:editor']);
    });

    test('shutdown checkpoint preflight failure leaves plugin active', () async {
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('editor', events);
      await manager.activate(plugin);

      final report = await PluginShutdownCoordinator(
        manager: manager,
        checkpointStore: _FailingStore(),
      ).shutdown(discoveredPlugins: [_discovered('editor')]);

      expect(report.succeeded, isFalse);
      expect(report.error, isA<StateError>());
      expect(manager.activePlugins, [same(plugin)]);
      expect(events, ['activate:editor']);
    });
  });
}

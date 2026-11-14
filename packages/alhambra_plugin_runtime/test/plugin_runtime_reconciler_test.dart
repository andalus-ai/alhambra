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

void main() {
  group('PluginRuntimeReconciler', () {
    test('seeds missing active snapshots from PluginManager', () async {
      final manager = PluginManager();
      await manager.activate(_Plugin('running'));
      final registry = PluginRuntimeHealthRegistry();

      final report = await PluginRuntimeReconciler(
        manager: manager,
        registry: registry,
      ).reconcile();

      expect(report.isConsistent, isFalse);
      expect(report.changes, hasLength(1));
      expect(report.changes.single.previousState, isNull);
      expect(report.changes.single.currentState, PluginRuntimeState.active);
      expect(registry.snapshotOf('running')!.state, PluginRuntimeState.active);
      expect(registry.history, isEmpty);
    });

    test('corrects stale active and in-progress projections to stopped', () async {
      final manager = PluginManager();
      final registry = PluginRuntimeHealthRegistry();
      registry.observe(pluginId: 'stale-active', state: PluginRuntimeState.active);
      registry.observe(pluginId: 'stale-starting', state: PluginRuntimeState.starting);
      registry.observe(pluginId: 'failed', state: PluginRuntimeState.failed);
      registry.observe(pluginId: 'validated', state: PluginRuntimeState.validated);

      final report = await PluginRuntimeReconciler(
        manager: manager,
        registry: registry,
      ).reconcile();

      expect(report.changes.map((change) => change.pluginId).toSet(),
          {'stale-active', 'stale-starting'});
      expect(registry.snapshotOf('stale-active')!.state, PluginRuntimeState.stopped);
      expect(registry.snapshotOf('stale-starting')!.state, PluginRuntimeState.stopped);
      expect(registry.snapshotOf('failed')!.state, PluginRuntimeState.failed);
      expect(registry.snapshotOf('validated')!.state, PluginRuntimeState.validated);
    });

    test('preserves historical transitions and transition counts on correction', () async {
      final manager = PluginManager();
      final registry = PluginRuntimeHealthRegistry();
      registry.transition(pluginId: 'plugin', next: PluginRuntimeState.validated);
      registry.transition(pluginId: 'plugin', next: PluginRuntimeState.starting);
      registry.transition(pluginId: 'plugin', next: PluginRuntimeState.failed);
      final historyBefore = registry.history.length;
      final countBefore = registry.snapshotOf('plugin')!.transitionCount;
      await manager.activate(_Plugin('plugin'));

      await PluginRuntimeReconciler(manager: manager, registry: registry).reconcile();

      expect(registry.snapshotOf('plugin')!.state, PluginRuntimeState.active);
      expect(registry.snapshotOf('plugin')!.transitionCount, countBefore);
      expect(registry.history, hasLength(historyBefore));
    });

    test('reports a stable no-op when projection already matches manager', () async {
      final manager = PluginManager();
      await manager.activate(_Plugin('healthy'));
      final registry = PluginRuntimeHealthRegistry();
      registry.observe(pluginId: 'healthy', state: PluginRuntimeState.active);

      final report = await PluginRuntimeReconciler(
        manager: manager,
        registry: registry,
      ).reconcile();

      expect(report.isConsistent, isTrue);
      expect(report.changes, isEmpty);
      expect(report.activePluginIds, ['healthy']);
    });
  });
}

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
  String id,
  PluginLifecycleCheckpointState state, {
  PluginLifecycleOperation operation = PluginLifecycleOperation.startup,
  int sequence = 0,
}) {
  final now = DateTime.utc(2026, 11, 13);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: 'op-$id',
    operation: operation,
    state: state,
    sequence: sequence,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PluginLifecycleRecoveryPlanner', () {
    test('classifies interrupted startup without invoking plugin hooks', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('starting', PluginLifecycleCheckpointState.starting));
      final manager = PluginManager();
      final report = await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect();

      expect(report.findings.single.disposition,
          PluginLifecycleRecoveryDisposition.startupOutcomeAmbiguous);
      expect(report.findings.single.requiresHostAction, isTrue);
      expect(manager.activePlugins, isEmpty);
      expect((await store.read('starting'))!.state,
          PluginLifecycleCheckpointState.starting);
    });

    test('recognizes startup completed before active checkpoint was persisted', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('editor', PluginLifecycleCheckpointState.starting));
      final manager = PluginManager();
      await manager.activate(_Plugin('editor'));

      final finding = (await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect()).findings.single;

      expect(finding.disposition,
          PluginLifecycleRecoveryDisposition.startupActiveCheckpointStale);
      expect(finding.isActive, isTrue);
    });

    test('recognizes shutdown completed before stopped checkpoint was persisted', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint(
        'editor',
        PluginLifecycleCheckpointState.stopping,
        operation: PluginLifecycleOperation.shutdown,
      ));

      final finding = (await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: PluginManager(),
      ).inspect()).findings.single;

      expect(finding.disposition,
          PluginLifecycleRecoveryDisposition.shutdownCompletedCheckpointStale);
    });

    test('identifies pending rollback and missing checkpoint for active plugin', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('rollback', PluginLifecycleCheckpointState.rollbackPending));
      final manager = PluginManager();
      await manager.activate(_Plugin('rollback'));
      await manager.activate(_Plugin('untracked'));

      final findings = (await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect()).findings;

      expect(findings.map((f) => f.pluginId), ['rollback', 'untracked']);
      expect(findings[0].disposition,
          PluginLifecycleRecoveryDisposition.rollbackRequired);
      expect(findings[1].disposition,
          PluginLifecycleRecoveryDisposition.activeWithoutCheckpoint);
    });

    test('distinguishes consistent, terminal failure, and stale active states', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('active', PluginLifecycleCheckpointState.active));
      await store.write(_checkpoint('failed', PluginLifecycleCheckpointState.failed));
      await store.write(_checkpoint('stale', PluginLifecycleCheckpointState.active));
      final manager = PluginManager();
      await manager.activate(_Plugin('active'));

      final findings = (await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect()).findings;

      expect(findings[0].disposition,
          PluginLifecycleRecoveryDisposition.consistentActive);
      expect(findings[1].disposition,
          PluginLifecycleRecoveryDisposition.terminalFailure);
      expect(findings[1].requiresHostAction, isTrue);
      expect(findings[2].disposition,
          PluginLifecycleRecoveryDisposition.staleActiveCheckpoint);
    });

    test('sorts findings and reports no automatic mutation', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('zeta', PluginLifecycleCheckpointState.planned));
      await store.write(_checkpoint('alpha', PluginLifecycleCheckpointState.stopped));
      final before = await store.readAll();
      final manager = PluginManager();

      final report = await PluginLifecycleRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect();

      expect(report.findings.map((f) => f.pluginId), ['alpha', 'zeta']);
      expect(report.isConsistent, isTrue);
      expect(await store.readAll(), before);
    });
  });
}

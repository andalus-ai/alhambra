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
  PluginLifecycleCheckpointState state,
) {
  final now = DateTime.utc(2026, 11, 13);
  return PluginLifecycleCheckpoint(
    pluginId: id,
    operationId: 'old-$id',
    operation: PluginLifecycleOperation.startup,
    state: state,
    sequence: 4,
    attempt: 2,
    createdAt: now,
    updatedAt: now,
    dependencyIds: const ['dependency'],
  );
}

PluginLifecycleRecoveryActionRequest _request(
  String id,
  PluginLifecycleRecoveryAction action, {
  String? summary,
  String? operationId,
}) =>
    PluginLifecycleRecoveryActionRequest(
      pluginId: id,
      expectedOperationId: 'old-$id',
      expectedSequence: 4,
      action: action,
      newOperationId: operationId ?? 'recovery-$id',
      failureSummary: summary,
      failureCode: 'HOST_REVIEW',
    );

void main() {
  group('PluginLifecycleRecoveryController', () {
    test('acknowledges verified active state using a new operation ID', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('active', PluginLifecycleCheckpointState.starting));
      final manager = PluginManager();
      await manager.activate(_Plugin('active'));

      final result = await PluginLifecycleRecoveryController(
        store: store,
        manager: manager,
      ).apply(_request('active', PluginLifecycleRecoveryAction.acknowledgeActive));

      expect(result.state, PluginLifecycleCheckpointState.active);
      expect(result.operationId, 'recovery-active');
      expect(result.sequence, 5);
      expect(result.dependencyIds, ['dependency']);
    });

    test('acknowledges stopped state only when manager reports inactive', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('stopped', PluginLifecycleCheckpointState.stopping));

      final result = await PluginLifecycleRecoveryController(
        store: store,
        manager: PluginManager(),
      ).apply(_request('stopped', PluginLifecycleRecoveryAction.acknowledgeStopped));

      expect(result.state, PluginLifecycleCheckpointState.stopped);
      expect(result.sequence, 5);
    });

    test('requires inactive plugin and a failure summary to mark failed', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin', PluginLifecycleCheckpointState.starting));
      final manager = PluginManager();
      await manager.activate(_Plugin('plugin'));
      final controller = PluginLifecycleRecoveryController(store: store, manager: manager);

      await expectLater(
        controller.apply(_request('plugin', PluginLifecycleRecoveryAction.markFailed,
            summary: 'Host verified activation could not be retained')),
        throwsStateError,
      );
      await manager.deactivate('plugin');

      await expectLater(
        controller.apply(_request('plugin', PluginLifecycleRecoveryAction.markFailed)),
        throwsArgumentError,
      );
      final result = await controller.apply(_request(
        'plugin',
        PluginLifecycleRecoveryAction.markFailed,
        summary: 'Host verified activation could not be retained',
      ));
      expect(result.state, PluginLifecycleCheckpointState.failed);
      expect(result.failureCode, 'HOST_REVIEW');
    });

    test('rejects stale operation ID or sequence', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin', PluginLifecycleCheckpointState.starting));
      final controller = PluginLifecycleRecoveryController(
        store: store,
        manager: PluginManager(),
      );
      final stale = PluginLifecycleRecoveryActionRequest(
        pluginId: 'plugin',
        expectedOperationId: 'old-plugin',
        expectedSequence: 3,
        action: PluginLifecycleRecoveryAction.acknowledgeStopped,
        newOperationId: 'recovery-stale',
      );
      await expectLater(controller.apply(stale), throwsStateError);
      final changed = _request('plugin', PluginLifecycleRecoveryAction.acknowledgeStopped);
      await controller.apply(changed);
      await expectLater(
        controller.apply(changed),
        throwsStateError,
      );
    });

    test('does not mutate plugin manager or invoke lifecycle hooks', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(_checkpoint('plugin', PluginLifecycleCheckpointState.starting));
      final manager = PluginManager();
      final before = manager.activePlugins;

      await PluginLifecycleRecoveryController(store: store, manager: manager).apply(
        _request('plugin', PluginLifecycleRecoveryAction.acknowledgeStopped),
      );

      expect(manager.activePlugins, before);
      expect((await store.read('plugin'))!.state, PluginLifecycleCheckpointState.stopped);
    });
  });
}

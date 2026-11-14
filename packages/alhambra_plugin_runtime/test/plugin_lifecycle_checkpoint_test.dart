import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginLifecycleCheckpoint checkpoint({
  String pluginId = 'editor',
  int sequence = 1,
  PluginLifecycleCheckpointState state = PluginLifecycleCheckpointState.planned,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return PluginLifecycleCheckpoint(
    pluginId: pluginId,
    operationId: 'startup-1',
    operation: PluginLifecycleOperation.startup,
    state: state,
    sequence: sequence,
    attempt: 1,
    createdAt: now,
    updatedAt: now,
    dependencyIds: ['core'],
  );
}

void main() {
  group('PluginLifecycleCheckpoint', () {
    test('copies dependency IDs into an immutable snapshot', () {
      final dependencies = ['core'];
      final value = PluginLifecycleCheckpoint(
        pluginId: 'editor',
        operationId: 'startup-1',
        operation: PluginLifecycleOperation.startup,
        state: PluginLifecycleCheckpointState.planned,
        sequence: 0,
        attempt: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        dependencyIds: dependencies,
      );
      dependencies.add('theme');
      expect(value.dependencyIds, ['core']);
      expect(() => value.dependencyIds.add('other'), throwsUnsupportedError);
    });

    test('identifies ambiguous in-flight phases', () {
      for (final state in [
        PluginLifecycleCheckpointState.starting,
        PluginLifecycleCheckpointState.stopping,
        PluginLifecycleCheckpointState.rollbackPending,
      ]) {
        expect(checkpoint(state: state).requiresRecovery, isTrue);
      }
      expect(checkpoint(state: PluginLifecycleCheckpointState.active)
          .requiresRecovery, isFalse);
    });

    test('validates identity, sequence and timestamp order', () {
      expect(() => checkpoint(pluginId: ' '), throwsArgumentError);
      expect(() => checkpoint(sequence: -1), throwsArgumentError);
      expect(() => PluginLifecycleCheckpoint(
        pluginId: 'editor',
        operationId: 'startup-1',
        operation: PluginLifecycleOperation.startup,
        state: PluginLifecycleCheckpointState.planned,
        sequence: 0,
        attempt: 1,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 1),
      ), throwsArgumentError);
    });
  });

  group('InMemoryPluginLifecycleCheckpointStore', () {
    test('writes, reads, lists and deletes records', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      final value = checkpoint();
      await store.write(value);
      expect(await store.read('editor'), same(value));
      expect(await store.readAll(), [same(value)]);
      await store.delete('editor');
      expect(await store.read('editor'), isNull);
      expect(await store.readAll(), isEmpty);
    });

    test('requires strictly increasing per-plugin sequence', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(checkpoint(sequence: 2));
      await expectLater(store.write(checkpoint(sequence: 2)), throwsStateError);
      await expectLater(store.write(checkpoint(sequence: 1)), throwsStateError);
      await store.write(checkpoint(sequence: 3));
      expect((await store.read('editor'))!.sequence, 3);
    });

    test('keeps independent plugin streams', () async {
      final store = InMemoryPluginLifecycleCheckpointStore();
      await store.write(checkpoint(pluginId: 'editor'));
      await store.write(checkpoint(pluginId: 'theme'));
      expect(await store.readAll(), hasLength(2));
    });
  });
}

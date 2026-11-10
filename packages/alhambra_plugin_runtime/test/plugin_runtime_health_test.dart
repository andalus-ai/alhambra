import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('PluginRuntimeHealthRegistry', () {
    test('records valid lifecycle transitions and immutable snapshots', () {
      final registry = PluginRuntimeHealthRegistry();
      final time = DateTime.utc(2026, 1, 2);

      registry.transition(pluginId: 'sample', next: PluginRuntimeState.validated, at: time);
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.starting, at: time);
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.active, at: time);

      final snapshot = registry.snapshotOf('sample')!;
      expect(snapshot.state, PluginRuntimeState.active);
      expect(snapshot.transitionCount, 3);
      expect(registry.history, hasLength(3));
      expect(() => registry.snapshots.clear(), throwsUnsupportedError);
      expect(() => registry.history.clear(), throwsUnsupportedError);
    });

    test('rejects illegal transitions without mutating state', () {
      final registry = PluginRuntimeHealthRegistry();
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.validated);

      expect(
        () => registry.transition(
          pluginId: 'sample',
          next: PluginRuntimeState.active,
        ),
        throwsA(isA<PluginRuntimeTransitionException>()),
      );
      expect(registry.snapshotOf('sample')!.state, PluginRuntimeState.validated);
      expect(registry.history, hasLength(1));
    });

    test('allows failed plugin to be rediscovered for a new attempt', () {
      final registry = PluginRuntimeHealthRegistry();
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.failed);
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.discovered);
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.validated);
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.starting);

      expect(registry.snapshotOf('sample')!.state, PluginRuntimeState.starting);
    });

    test('rejects blank plugin IDs', () {
      final registry = PluginRuntimeHealthRegistry();
      expect(
        () => registry.transition(pluginId: ' ', next: PluginRuntimeState.validated),
        throwsArgumentError,
      );
    });

    test('observes an existing state without inventing transition history', () {
      final registry = PluginRuntimeHealthRegistry();
      final snapshot = registry.observe(
        pluginId: 'already-running',
        state: PluginRuntimeState.active,
        reason: 'Attached to existing host',
      );

      expect(snapshot.state, PluginRuntimeState.active);
      expect(snapshot.transitionCount, 0);
      expect(registry.history, isEmpty);
      expect(registry.observe(
        pluginId: 'already-running',
        state: PluginRuntimeState.failed,
      ).state, PluginRuntimeState.active);
    });

    test('forget removes projection but retains historical transitions', () {
      final registry = PluginRuntimeHealthRegistry();
      registry.transition(pluginId: 'sample', next: PluginRuntimeState.validated);
      registry.forget('sample');

      expect(registry.snapshotOf('sample'), isNull);
      expect(registry.history, hasLength(1));
    });
  });
}

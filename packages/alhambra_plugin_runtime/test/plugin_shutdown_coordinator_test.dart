import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _RecordingPlugin implements AlhambraPlugin {
  _RecordingPlugin(
    this.id,
    this.events, {
    this.failDeactivation = false,
  });

  final String id;
  final List<String> events;
  final bool failDeactivation;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: id,
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    events.add('activate:$id');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    events.add('deactivate:$id');
    if (failDeactivation) {
      throw StateError('deactivation failed: $id');
    }
  }
}

DiscoveredPlugin _discovered(
  String id, {
  List<String> dependencies = const [],
}) {
  return DiscoveredPlugin(
    manifest: ExtensionManifest(
      id: id,
      name: id,
      version: '1.0.0',
      dependencies: dependencies,
    ),
    directory: Directory('/plugins/$id'),
  );
}

void main() {
  group('PluginShutdownCoordinator', () {
    test('deactivates active plugins in reverse dependency order', () async {
      final events = <String>[];
      final manager = PluginManager();
      final core = _RecordingPlugin('core', events);
      final theme = _RecordingPlugin('theme', events);
      final editor = _RecordingPlugin('editor', events);
      final unrelated = _RecordingPlugin('unrelated', events);

      await manager.activate(core);
      await manager.activate(theme);
      await manager.activate(editor);
      await manager.activate(unrelated);

      final report = await PluginShutdownCoordinator(
        manager: manager,
      ).shutdown(
        discoveredPlugins: [
          _discovered('editor', dependencies: ['theme']),
          _discovered('core'),
          _discovered('theme', dependencies: ['core']),
        ],
      );

      expect(report.succeeded, isTrue);
      expect(report.attemptedPluginIds, ['editor', 'theme', 'core']);
      expect(report.deactivatedPluginIds, ['editor', 'theme', 'core']);
      expect(report.untouchedActivePluginIds, ['unrelated']);
      expect(report.failures, isEmpty);
      expect(events, [
        'activate:core',
        'activate:theme',
        'activate:editor',
        'activate:unrelated',
        'deactivate:editor',
        'deactivate:theme',
        'deactivate:core',
      ]);
      expect(manager.activePlugins, [same(unrelated)]);
    });

    test('continues shutting down remaining plugins after a failure', () async {
      final events = <String>[];
      final manager = PluginManager();
      final core = _RecordingPlugin('core', events);
      final theme = _RecordingPlugin(
        'theme',
        events,
        failDeactivation: true,
      );
      final editor = _RecordingPlugin('editor', events);

      await manager.activate(core);
      await manager.activate(theme);
      await manager.activate(editor);

      final report = await PluginShutdownCoordinator(
        manager: manager,
      ).shutdown(
        discoveredPlugins: [
          _discovered('core'),
          _discovered('theme', dependencies: ['core']),
          _discovered('editor', dependencies: ['theme']),
        ],
      );

      expect(report.succeeded, isFalse);
      expect(report.attemptedPluginIds, ['editor', 'theme', 'core']);
      expect(report.deactivatedPluginIds, ['editor', 'core']);
      expect(report.failures, hasLength(1));
      expect(report.failures.single.pluginId, 'theme');
      expect(report.failures.single.error, isA<StateError>());
      expect(events, [
        'activate:core',
        'activate:theme',
        'activate:editor',
        'deactivate:editor',
        'deactivate:theme',
        'deactivate:core',
      ]);
      // PluginManager guarantees host-owned cleanup and removes the plugin
      // from active state even when its shutdown hook fails.
      expect(manager.activePlugins, isEmpty);
    });

    test('invalid dependency graph prevents every shutdown callback', () async {
      final events = <String>[];
      final manager = PluginManager();
      final core = _RecordingPlugin('core', events);
      await manager.activate(core);

      final report = await PluginShutdownCoordinator(
        manager: manager,
      ).shutdown(
        discoveredPlugins: [
          _discovered('editor', dependencies: ['missing']),
          _discovered('core'),
        ],
      );

      expect(report.succeeded, isFalse);
      expect(report.error, isA<PluginDependencyResolutionException>());
      expect(report.attemptedPluginIds, isEmpty);
      expect(events, ['activate:core']);
      expect(manager.activePlugins, [same(core)]);
    });

    test('skips discovered plugins that are not currently active', () async {
      final events = <String>[];
      final manager = PluginManager();
      final core = _RecordingPlugin('core', events);
      await manager.activate(core);

      final report = await PluginShutdownCoordinator(
        manager: manager,
      ).shutdown(
        discoveredPlugins: [
          _discovered('core'),
          _discovered('optional', dependencies: ['core']),
        ],
      );

      expect(report.succeeded, isTrue);
      expect(report.attemptedPluginIds, ['core']);
      expect(report.deactivatedPluginIds, ['core']);
      expect(events, ['activate:core', 'deactivate:core']);
    });

    test('returns immutable report collections', () async {
      final events = <String>[];
      final manager = PluginManager();
      final core = _RecordingPlugin('core', events);
      await manager.activate(core);

      final report = await PluginShutdownCoordinator(
        manager: manager,
      ).shutdown(discoveredPlugins: [_discovered('core')]);

      expect(
        () => report.attemptedPluginIds.add('other'),
        throwsUnsupportedError,
      );
      expect(
        () => report.deactivatedPluginIds.add('other'),
        throwsUnsupportedError,
      );
    });
  });
}

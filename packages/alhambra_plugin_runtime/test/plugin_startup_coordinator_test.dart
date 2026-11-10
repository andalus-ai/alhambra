import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _RecordingPlugin implements AlhambraPlugin {
  _RecordingPlugin(
    this.id,
    this.events, {
    this.failActivation = false,
  });

  final String id;
  final List<String> events;
  final bool failActivation;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: id,
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    events.add('activate:$id');
    if (failActivation) throw StateError('activation failed: $id');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    events.add('deactivate:$id');
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
  group('PluginStartupCoordinator', () {
    test('activates in dependency order', () async {
      final events = <String>[];
      final core = _RecordingPlugin('core', events);
      final editor = _RecordingPlugin('editor', events);
      final coordinator = PluginStartupCoordinator(
        manager: PluginManager(),
      );

      final report = await coordinator.start(
        discoveredPlugins: [
          _discovered('editor', dependencies: ['core']),
          _discovered('core'),
        ],
        compiledPlugins: {'core': core, 'editor': editor},
      );

      expect(report.succeeded, isTrue);
      expect(report.activatedPluginIds, ['core', 'editor']);
      expect(events, ['activate:core', 'activate:editor']);
    });

    test('rolls back newly activated plugins in reverse order', () async {
      final events = <String>[];
      final core = _RecordingPlugin('core', events);
      final theme = _RecordingPlugin('theme', events);
      final editor = _RecordingPlugin(
        'editor',
        events,
        failActivation: true,
      );
      final coordinator = PluginStartupCoordinator(
        manager: PluginManager(),
      );

      final report = await coordinator.start(
        discoveredPlugins: [
          _discovered('core'),
          _discovered('theme', dependencies: ['core']),
          _discovered('editor', dependencies: ['theme']),
        ],
        compiledPlugins: {
          'core': core,
          'theme': theme,
          'editor': editor,
        },
      );

      expect(report.succeeded, isFalse);
      expect(report.failedPluginId, 'editor');
      expect(report.error, isA<StateError>());
      expect(report.activatedPluginIds, ['core', 'theme']);
      expect(report.rolledBackPluginIds, ['theme', 'core']);
      expect(report.rollbackFailures, isEmpty);
      expect(
        events,
        [
          'activate:core',
          'activate:theme',
          'activate:editor',
          'deactivate:theme',
          'deactivate:core',
        ],
      );
    });

    test('preflight failure prevents every activation', () async {
      final events = <String>[];
      final core = _RecordingPlugin('core', events);
      final coordinator = PluginStartupCoordinator(
        manager: PluginManager(),
      );

      final report = await coordinator.start(
        discoveredPlugins: [
          _discovered('editor', dependencies: ['missing']),
          _discovered('core'),
        ],
        compiledPlugins: {'core': core},
      );

      expect(report.succeeded, isFalse);
      expect(report.error, isA<PluginDependencyResolutionException>());
      expect(events, isEmpty);
    });

    test('does not roll back plugins active before this batch', () async {
      final events = <String>[];
      final manager = PluginManager();
      final preexisting = _RecordingPlugin('preexisting', events);
      await manager.activate(preexisting);

      final next = _RecordingPlugin('next', events);
      final failing = _RecordingPlugin(
        'failing',
        events,
        failActivation: true,
      );
      final coordinator = PluginStartupCoordinator(manager: manager);

      final report = await coordinator.start(
        discoveredPlugins: [
          _discovered('preexisting'),
          _discovered('next', dependencies: ['preexisting']),
          _discovered('failing', dependencies: ['next']),
        ],
        compiledPlugins: {
          'preexisting': preexisting,
          'next': next,
          'failing': failing,
        },
      );

      expect(report.succeeded, isFalse);
      expect(report.activatedPluginIds, ['next']);
      expect(report.rolledBackPluginIds, ['next']);
      expect(manager.activePlugins, [same(preexisting)]);
      expect(events, [
        'activate:preexisting',
        'activate:next',
        'activate:failing',
        'deactivate:next',
      ]);
    });

    test('rejects manifest and compiled plugin identity mismatch', () async {
      final events = <String>[];
      final plugin = _RecordingPlugin('runtime.id', events);
      final coordinator = PluginStartupCoordinator(
        manager: PluginManager(),
      );

      final report = await coordinator.start(
        discoveredPlugins: [_discovered('manifest.id')],
        compiledPlugins: {'manifest.id': plugin},
      );

      expect(report.succeeded, isFalse);
      expect(report.error, isA<PluginStartupValidationException>());
      expect(events, isEmpty);
    });
  });
}

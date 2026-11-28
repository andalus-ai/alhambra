import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_host/alhambra_plugin_host.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Plugin implements AlhambraPlugin {
  _Plugin(this.id, this.events, {this.failStop = false});

  final String id;
  final List<String> events;
  final bool failStop;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: id,
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    events.add('start:$id');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    events.add('stop:$id');
    if (failStop) throw StateError('stop failed: $id');
  }
}

DiscoveredPlugin _discovered(String id, {List<String> dependencies = const []}) {
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
  group('PluginHostLifecycle', () {
    test('starts plugins and disposes resources after reverse-order shutdown',
        () async {
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('app.plugin', events);
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [_discovered('app.plugin')],
        compiledPlugins: {'app.plugin': plugin},
        resources: [
          PluginHostResource(id: 'database', dispose: () async {
            events.add('close:database');
          }),
          PluginHostResource(id: 'http', dispose: () async {
            events.add('close:http');
          }),
        ],
      );

      final started = await host.start();
      expect(started.succeeded, isTrue);
      expect(host.state, PluginHostState.running);

      final stopped = await host.shutdown();
      expect(stopped.succeeded, isTrue);
      expect(stopped.resourcesDisposed, isTrue);
      expect(host.state, PluginHostState.stopped);
      expect(events, [
        'start:app.plugin',
        'stop:app.plugin',
        'close:http',
        'close:database',
      ]);
      expect((await host.shutdown()).succeeded, isTrue);
    });

    test('closes resources after plugin shutdown hook failure', () async {
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('app.plugin', events, failStop: true);
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [_discovered('app.plugin')],
        compiledPlugins: {'app.plugin': plugin},
        resources: [
          PluginHostResource(id: 'store', dispose: () async {
            events.add('close:store');
          }),
        ],
      );

      expect((await host.start()).succeeded, isTrue);
      final report = await host.shutdown();

      expect(report.succeeded, isFalse);
      expect(report.pluginReport!.failures.single.pluginId, 'app.plugin');
      expect(report.resourcesDisposed, isTrue);
      expect(events, ['start:app.plugin', 'stop:app.plugin', 'close:store']);
    });

    test('disposes resources in reverse order after startup failure', () async {
      final events = <String>[];
      final manager = PluginManager();
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [_discovered('missing')],
        compiledPlugins: {},
        resources: [
          PluginHostResource(id: 'first', dispose: () async {
            events.add('close:first');
          }),
          PluginHostResource(id: 'second', dispose: () async {
            events.add('close:second');
          }),
        ],
      );

      final report = await host.start();
      expect(report.succeeded, isFalse);
      expect(host.state, PluginHostState.failed);
      expect(events, ['close:second', 'close:first']);
    });

    test('continues resource disposal when one resource fails', () async {
      final events = <String>[];
      final manager = PluginManager();
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [],
        compiledPlugins: {},
        resources: [
          PluginHostResource(id: 'first', dispose: () async {
            events.add('close:first');
            throw StateError('close failed');
          }),
          PluginHostResource(id: 'second', dispose: () async {
            events.add('close:second');
          }),
        ],
      );

      final report = await host.shutdown();
      expect(report.succeeded, isFalse);
      expect(report.resourcesDisposed, isTrue);
      expect(report.resourceFailures.single.resourceId, 'first');
      expect(events, ['close:second', 'close:first']);
    });

    test('retries failed resource disposal without repeating plugin shutdown',
        () async {
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('app.plugin', events);
      var disposeAttempts = 0;
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [_discovered('app.plugin')],
        compiledPlugins: {'app.plugin': plugin},
        resources: [
          PluginHostResource(id: 'store', dispose: () async {
            disposeAttempts++;
            events.add('close:store:$disposeAttempts');
            if (disposeAttempts == 1) throw StateError('temporary close failure');
          }),
        ],
      );

      expect((await host.start()).succeeded, isTrue);
      final first = await host.shutdown();
      expect(first.succeeded, isFalse);
      expect(first.resourcesDisposed, isFalse);
      expect(first.pluginReport!.attemptedPluginIds, ['app.plugin']);

      final second = await host.shutdown();
      expect(second.succeeded, isTrue);
      expect(second.resourcesDisposed, isTrue);
      expect(events, [
        'start:app.plugin',
        'stop:app.plugin',
        'close:store:1',
        'close:store:2',
      ]);
    });

    test('retains dependencies and permits shutdown retry after preflight failure',
        () async {
      final events = <String>[];
      final manager = PluginManager();
      final plugin = _Plugin('app.plugin', events);
      final host = PluginHostLifecycle(
        startupCoordinator: PluginStartupCoordinator(manager: manager),
        shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
        discoveredPlugins: [_discovered('app.plugin')],
        compiledPlugins: {'app.plugin': plugin},
        resources: [
          PluginHostResource(id: 'store', dispose: () async {
            events.add('close:store');
          }),
        ],
      );

      // The invalid graph is discovered during shutdown preflight. The host
      // retains the store because the plugin remains active.
      expect((await host.start()).succeeded, isTrue);
      final first = await host.shutdown(
        discoveredPlugins: [
          _discovered('app.plugin', dependencies: ['missing']),
        ],
      );
      expect(first.resourcesDisposed, isFalse);
      expect(host.state, PluginHostState.running);
      expect(events, ['start:app.plugin']);

      final retry = await host.shutdown(
        discoveredPlugins: [_discovered('app.plugin')],
      );
      expect(retry.succeeded, isTrue);
      expect(retry.resourcesDisposed, isTrue);
      expect(events, ['start:app.plugin', 'stop:app.plugin', 'close:store']);
    });

    test('rejects duplicate resource IDs', () {
      final manager = PluginManager();
      expect(
        () => PluginHostLifecycle(
          startupCoordinator: PluginStartupCoordinator(manager: manager),
          shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
          discoveredPlugins: [],
          compiledPlugins: {},
          resources: [
            PluginHostResource(id: 'duplicate', dispose: () async {}),
            PluginHostResource(id: 'duplicate', dispose: () async {}),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

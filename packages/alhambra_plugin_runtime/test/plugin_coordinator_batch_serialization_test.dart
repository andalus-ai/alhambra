import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _GatePlugin implements AlhambraPlugin {
  _GatePlugin(this.id, this.events, {this.onActivate});

  final String id;
  final List<String> events;
  final Future<void> Function()? onActivate;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: id,
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    events.add('activate:start:$id');
    await onActivate?.call();
    events.add('activate:end:$id');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    events.add('deactivate:$id');
  }
}

DiscoveredPlugin _discovered(String id) => DiscoveredPlugin(
      manifest: ExtensionManifest(id: id, name: id, version: '1.0.0'),
      directory: Directory('/plugins/$id'),
    );

void main() {
  group('coordinator lifecycle batch serialization', () {
    test('queues concurrent startup batches on the shared manager', () async {
      final manager = PluginManager();
      final events = <String>[];
      final entered = Completer<void>();
      final release = Completer<void>();
      final first = _GatePlugin('first', events, onActivate: () async {
        entered.complete();
        await release.future;
      });
      final second = _GatePlugin('second', events);

      final firstFuture = PluginStartupCoordinator(manager: manager).start(
        discoveredPlugins: [_discovered('first')],
        compiledPlugins: {'first': first},
      );
      await entered.future;
      final secondFuture = PluginStartupCoordinator(manager: manager).start(
        discoveredPlugins: [_discovered('second')],
        compiledPlugins: {'second': second},
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, ['activate:start:first']);
      release.complete();

      final reports = await Future.wait([firstFuture, secondFuture]);
      expect(reports.every((report) => report.succeeded), isTrue);
      expect(events, [
        'activate:start:first',
        'activate:end:first',
        'activate:start:second',
        'activate:end:second',
      ]);
    });

    test('prevents shutdown from interleaving with startup', () async {
      final manager = PluginManager();
      final events = <String>[];
      final entered = Completer<void>();
      final release = Completer<void>();
      final plugin = _GatePlugin('shared', events, onActivate: () async {
        entered.complete();
        await release.future;
      });
      final startup = PluginStartupCoordinator(manager: manager).start(
        discoveredPlugins: [_discovered('shared')],
        compiledPlugins: {'shared': plugin},
      );
      await entered.future;

      final shutdown = PluginShutdownCoordinator(manager: manager).shutdown(
        discoveredPlugins: [_discovered('shared')],
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, ['activate:start:shared']);

      release.complete();
      final startReport = await startup;
      final stopReport = await shutdown;
      expect(startReport.succeeded, isTrue);
      expect(stopReport.succeeded, isTrue);
      expect(events, [
        'activate:start:shared',
        'activate:end:shared',
        'deactivate:shared',
      ]);
      expect(manager.activePlugins, isEmpty);
    });

    test('releases the batch gate when a batch throws unexpectedly', () async {
      final manager = PluginManager();
      final events = <String>[];
      final entered = Completer<void>();
      final release = Completer<void>();
      final first = manager.runExclusiveLifecycleBatch(() async {
        entered.complete();
        await release.future;
        throw StateError('batch failed');
      });
      await entered.future;
      final second = manager.runExclusiveLifecycleBatch(() async {
        events.add('second');
        return true;
      });
      release.complete();
      await expectLater(first, throwsA(isA<StateError>()));
      expect(await second, isTrue);
      expect(events, ['second']);
    });
  });
}

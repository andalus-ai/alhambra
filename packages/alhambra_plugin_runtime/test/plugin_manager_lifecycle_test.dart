import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _FailingDeactivatePlugin implements AlhambraPlugin {
  _FailingDeactivatePlugin({this.failOnDeactivate = true});

  final bool failOnDeactivate;
  int activationCount = 0;
  int deactivationCount = 0;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test.lifecycle',
        name: 'Lifecycle test plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    activationCount++;
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    deactivationCount++;
    if (failOnDeactivate) {
      throw StateError('shutdown failed');
    }
  }
}

class _BlockingPlugin implements AlhambraPlugin {
  _BlockingPlugin({
    required this.id,
    required this.activationGate,
    required this.activationStarted,
  });

  final String id;
  final Completer<void> activationGate;
  final Completer<void> activationStarted;
  int activationCount = 0;
  int deactivationCount = 0;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: 'Blocking plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    activationCount++;
    if (!activationStarted.isCompleted) activationStarted.complete();
    await activationGate.future;
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    deactivationCount++;
  }
}

void main() {
  group('PluginManager lifecycle cleanup', () {
    test('removes plugin from active state when deactivate throws', () async {
      final manager = PluginManager();
      final plugin = _FailingDeactivatePlugin();

      await manager.activate(plugin);
      expect(manager.activePlugins, contains(plugin));

      await expectLater(
        manager.deactivate(plugin.metadata.id),
        throwsA(isA<StateError>()),
      );

      expect(manager.activePlugins, isEmpty);
    });

    test('allows activation again after failed deactivation', () async {
      final manager = PluginManager();
      final plugin = _FailingDeactivatePlugin();

      await manager.activate(plugin);
      await expectLater(
        manager.deactivate(plugin.metadata.id),
        throwsA(isA<StateError>()),
      );

      await manager.activate(plugin);

      expect(plugin.activationCount, 2);
      expect(manager.activePlugins, hasLength(1));
      expect(manager.activePlugins.single, same(plugin));
    });

    test('deactivation of an unknown plugin is a no-op', () async {
      final manager = PluginManager();

      await expectLater(manager.deactivate('missing.plugin'), completes);
      expect(manager.activePlugins, isEmpty);
    });

    test('serializes concurrent activation of the same plugin', () async {
      final manager = PluginManager();
      final gate = Completer<void>();
      final started = Completer<void>();
      final plugin = _BlockingPlugin(
        id: 'test.concurrent-activation',
        activationGate: gate,
        activationStarted: started,
      );

      final first = manager.activate(plugin);
      await started.future;
      final second = manager.activate(plugin);

      gate.complete();
      await Future.wait([first, second]);

      expect(plugin.activationCount, 1);
      expect(manager.activePlugins, hasLength(1));
    });

    test('serializes concurrent deactivation of the same plugin', () async {
      final manager = PluginManager();
      final gate = Completer<void>();
      final started = Completer<void>();
      final plugin = _BlockingPlugin(
        id: 'test.concurrent-deactivation',
        activationGate: gate,
        activationStarted: started,
      );

      final activation = manager.activate(plugin);
      await started.future;
      gate.complete();
      await activation;

      await Future.wait([
        manager.deactivate(plugin.metadata.id),
        manager.deactivate(plugin.metadata.id),
      ]);

      expect(plugin.deactivationCount, 1);
      expect(manager.activePlugins, isEmpty);
    });

    test('rejects an empty plugin identifier', () async {
      final manager = PluginManager();
      final plugin = _EmptyIdPlugin();

      await expectLater(
        manager.activate(plugin),
        throwsA(isA<ArgumentError>()),
      );
      expect(manager.activePlugins, isEmpty);
    });
  });
}

class _EmptyIdPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: ' ',
        name: 'Invalid plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {}

  @override
  Future<void> deactivate(PluginContext context) async {}
}

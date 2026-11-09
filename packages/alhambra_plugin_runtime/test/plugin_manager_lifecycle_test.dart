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
  });
}

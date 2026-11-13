import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/greeting_plugin.dart';

void main() {
  group('GreetingPlugin', () {
    test('activates idempotently and deactivates through PluginManager', () async {
      final manager = PluginManager();
      final plugin = GreetingPlugin();

      await manager.activate(plugin);
      await manager.activate(plugin);

      expect(plugin.metadata.id, GreetingPlugin.pluginId);

      await manager.deactivate(GreetingPlugin.pluginId);
      await manager.deactivate(GreetingPlugin.pluginId);
    });
  });
}

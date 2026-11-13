import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/greeting_plugin.dart';

void main() {
  group('GreetingPlugin', () {
    test('registers contributions and removes them on deactivation', () async {
      final manager = PluginManager();
      final plugin = GreetingPlugin();

      await manager.activate(plugin);
      await manager.activate(plugin);

      expect(manager.runtime.commands.contains('example.greeting.sayHello'), isTrue);
      expect(
        manager.runtime.views.getAll().map((view) => view.id),
        contains('example.greeting.welcome'),
      );
      expect(
        manager.runtime.settings.getAll().map((page) => page.id),
        contains('example.greeting.settings'),
      );

      await manager.deactivate(GreetingPlugin.pluginId);
      await manager.deactivate(GreetingPlugin.pluginId);

      expect(manager.runtime.commands.contains('example.greeting.sayHello'), isFalse);
      expect(
        manager.runtime.views.getAll().map((view) => view.id),
        isNot(contains('example.greeting.welcome')),
      );
      expect(
        manager.runtime.settings.getAll().map((page) => page.id),
        isNot(contains('example.greeting.settings')),
      );
    });
  });
}

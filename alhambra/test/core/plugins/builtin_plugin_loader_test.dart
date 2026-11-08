import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra/core/plugins/builtin_plugin_loader.dart';
import 'package:alhambra/plugins/backend_monitor/backend_monitor_plugin.dart';
import 'package:alhambra/plugins/dashboard/dashboard_plugin.dart';
import 'package:alhambra/plugins/explorer/explorer_plugin.dart';
import 'package:alhambra/plugins/log/log_plugin.dart';
import 'package:alhambra/plugins/marketplace/marketplace_plugin.dart';
import 'package:alhambra/plugins/navigation/navigation_plugin.dart';
import 'package:alhambra/plugins/settings/settings_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature-as-Plugin Architecture & BuiltInPluginLoader Tests', () {
    late ExtensionRuntime runtime;
    late PluginManager pluginManager;
    late BuiltInPluginLoader loader;

    setUp(() {
      runtime = ExtensionRuntime();
      pluginManager = PluginManager(runtime: runtime);
      loader = BuiltInPluginLoader(pluginManager: pluginManager);
    });

    test('BuiltInPluginLoader activates all 7 neutral platform core plugins', () async {
      await loader.loadAll();

      final activeIds = pluginManager.activePlugins.map((p) => p.metadata.id).toSet();

      final expectedPlugins = [
        NavigationPlugin.pluginId,
        SettingsPlugin.pluginId,
        BackendMonitorPlugin.pluginId,
        ExplorerPlugin.pluginId,
        MarketplacePlugin.pluginId,
        LogPlugin.pluginId,
        DashboardPlugin.pluginId,
      ];

      for (final id in expectedPlugins) {
        expect(activeIds.contains(id), isTrue, reason: 'Plugin $id should be active');
      }
      expect(activeIds.length, equals(7));
    });

    test('All contributed platform views are registered in ViewRegistry', () async {
      await loader.loadAll();

      final views = runtime.views.all.map((v) => v.id).toSet();

      final expectedViewIds = [
        ExplorerPlugin.viewId,
        MarketplacePlugin.viewId,
        DashboardPlugin.viewId,
      ];

      for (final id in expectedViewIds) {
        expect(views.contains(id), isTrue, reason: 'View $id should be registered');
      }
    });
  });
}

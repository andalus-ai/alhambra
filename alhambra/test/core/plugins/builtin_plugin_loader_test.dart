import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra/core/plugins/builtin_plugin_loader.dart';
import 'package:alhambra/core/plugins/alhambra_community_plugin_bundle.dart';
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
      loader = BuiltInPluginLoader(
        pluginManager: pluginManager,
        platformPlugins: AlhambraCommunityPluginBundle.createPlatformPlugins(),
      );
    });

    test('BuiltInPluginLoader activates only the explicitly supplied community plugins', () async {
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

    test('loader has no implicit built-in plugins', () async {
      final isolatedManager = PluginManager(runtime: ExtensionRuntime());
      final report = await BuiltInPluginLoader(
        pluginManager: isolatedManager,
      ).loadAll();

      expect(report.activatedPluginIds, isEmpty);
      expect(report.failures, isEmpty);
      expect(isolatedManager.activePlugins, isEmpty);
    });

    test('loader reports plugin activation failures and continues', () async {
      final isolatedManager = PluginManager(runtime: ExtensionRuntime());
      final report = await BuiltInPluginLoader(
        pluginManager: isolatedManager,
        platformPlugins: [_FailingPlugin(), DashboardPlugin()],
      ).loadAll();

      expect(report.hasFailures, isTrue);
      expect(report.failures.single.pluginId, 'test.failing');
      expect(report.activatedPluginIds, contains(DashboardPlugin.pluginId));
      expect(
        isolatedManager.activePlugins.map((plugin) => plugin.metadata.id),
        contains(DashboardPlugin.pluginId),
      );
    });

  });
}

final class _FailingPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test.failing',
        name: 'Failing test plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    throw StateError('activation failed');
  }
}

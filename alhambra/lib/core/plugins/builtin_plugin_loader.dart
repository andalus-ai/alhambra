import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../plugins/backend_monitor/backend_monitor_plugin.dart';
import '../../plugins/dashboard/dashboard_plugin.dart';
import '../../plugins/log/log_plugin.dart';
import '../../plugins/marketplace/marketplace_plugin.dart';
import '../../plugins/navigation/navigation_plugin.dart';
import '../../plugins/settings/settings_plugin.dart';
import '../../plugins/explorer/explorer_plugin.dart';
import '../commands/workbench_commands.dart';

/// Central bootstrapper for the Workbench Platform.
/// Loads agnostic platform core plugins and modular domain plugin packs.
class BuiltInPluginLoader {
  final PluginManager pluginManager;
  final List<AlhambraPlugin>? domainPluginPacks;

  BuiltInPluginLoader({
    required this.pluginManager,
    this.domainPluginPacks,
  });

  /// The neutral, agnostic platform plugins that form the Workbench Foundation:
  /// Navigation & Shell, Settings, Plugin Store, Telemetry & Diagnostics, Infrastructure.
  static List<AlhambraPlugin> get platformCorePlugins => [
        NavigationPlugin(),
        SettingsPlugin(),
        MarketplacePlugin(),
        DashboardPlugin(),
        BackendMonitorPlugin(),
        LogPlugin(),
        ExplorerPlugin(),
      ];

  /// Default domain plugin packs (neutral platform has no domain-specific packs by default).
  static List<AlhambraPlugin> get defaultDomainPacks => const [];

  Future<void> loadAll() async {
    // 1. Load Neutral Workbench Platform Core Plugins
    for (final plugin in platformCorePlugins) {
      try {
        await pluginManager.activate(plugin);
      } catch (_) {}
    }

    // 2. Load Domain Plugin Packs (e.g. Coding Agent Pack, Low-Code Pack, etc. provided by host app)
    final packs = domainPluginPacks ?? defaultDomainPacks;
    for (final pack in packs) {
      try {
        await pluginManager.activate(pack);
      } catch (_) {}
    }

    // 3. Register workbench commands
    WorkbenchCommands.registerAll(
      commandRegistry: pluginManager.runtime.commands,
      workbench: pluginManager.runtime.workbench,
      workspaceModeController: pluginManager.runtime.workspaceModeController,
    );
  }
}

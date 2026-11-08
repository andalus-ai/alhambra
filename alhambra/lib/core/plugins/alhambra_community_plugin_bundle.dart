import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../plugins/backend_monitor/backend_monitor_plugin.dart';
import '../../plugins/dashboard/dashboard_plugin.dart';
import '../../plugins/explorer/explorer_plugin.dart';
import '../../plugins/log/log_plugin.dart';
import '../../plugins/marketplace/marketplace_plugin.dart';
import '../../plugins/navigation/navigation_plugin.dart';
import '../../plugins/settings/settings_plugin.dart';

/// The default composition chosen by the standalone Alhambra Community app.
///
/// Other applications should construct their own plugin list and pass it to
/// the generic plugin loader. Keeping this composition in the app layer means the
/// generic loader does not pull these implementations into every adopter.
abstract final class AlhambraCommunityPluginBundle {
  static List<AlhambraPlugin> createPlatformPlugins() => [
        NavigationPlugin(),
        SettingsPlugin(),
        MarketplacePlugin(),
        DashboardPlugin(),
        BackendMonitorPlugin(),
        LogPlugin(),
        ExplorerPlugin(),
      ];
}

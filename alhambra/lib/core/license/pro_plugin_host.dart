import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'edition.dart';

class ProPluginHost {
  final PluginManager pluginManager;
  final List<AlhambraPlugin> proPlugins;

  ProPluginHost({
    required this.pluginManager,
    this.proPlugins = const [],
  });

  Future<void> syncPlugins(AlhambraEdition edition) async {
    if (edition.isProOrHigher) {
      for (final plugin in proPlugins) {
        try {
          await pluginManager.activate(plugin);
        } catch (_) {}
      }
    } else {
      for (final plugin in proPlugins) {
        try {
          await pluginManager.deactivate(plugin.metadata.id);
        } catch (_) {}
      }
    }
  }
}

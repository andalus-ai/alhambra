import 'plugin_context.dart';
import 'plugin_metadata.dart';

/// Abstract interface for Alhambra plugins.
abstract interface class AlhambraPlugin {
  /// The metadata for the plugin.
  PluginMetadata get metadata;

  /// Activates the plugin.
  /// [context] - The plugin context.
  Future<void> activate(PluginContext context);

  /// Deactivates the plugin.
  /// [context] - The plugin context.
  Future<void> deactivate(PluginContext context) async {}
}

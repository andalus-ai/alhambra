import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'plugin_contribution_snapshot.dart';

/// Small in-process host for testing plugin lifecycle and contribution cleanup.
///
/// The host intentionally uses the same [PluginManager] and
/// [ExtensionRuntime] as an application host. It does not mock lifecycle
/// behavior or provide code isolation.
final class AlhambraPluginTestHost {
  AlhambraPluginTestHost({PluginManager? manager})
      : manager = manager ?? PluginManager();

  final PluginManager manager;

  ExtensionRuntime get runtime => manager.runtime;

  List<String> get activePluginIds => List<String>.unmodifiable(
        manager.activePlugins.map((plugin) => plugin.metadata.id),
      );

  bool isActive(String pluginId) => activePluginIds.contains(pluginId);

  Future<void> activate(AlhambraPlugin plugin) => manager.activate(plugin);

  Future<void> deactivate(String pluginId) => manager.deactivate(pluginId);

  PluginContributionSnapshot snapshot() =>
      PluginContributionSnapshot.capture(runtime);

  /// Deactivates every currently active plugin, attempting all cleanups.
  ///
  /// If one or more plugins fail to deactivate, the first error is rethrown
  /// after every active plugin has been attempted.
  Future<void> close() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    final pluginIds = activePluginIds.reversed.toList(growable: false);
    for (final pluginId in pluginIds) {
      try {
        await deactivate(pluginId);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

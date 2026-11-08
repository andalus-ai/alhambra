import 'dart:async';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../extensions/extension_runtime.dart';
import 'runtime_plugin_context.dart';

/// 
class PluginManager {
  final Map<String, AlhambraPlugin> _activePlugins = {};
  final Map<String, RuntimePluginContext> _contexts = {};
  final ExtensionRuntime runtime;

  /// 
  PluginManager({ExtensionRuntime? runtime})
      : runtime = runtime ?? ExtensionRuntime();

  /// 
  Future<void> activate(AlhambraPlugin plugin) async {
    if (_activePlugins.containsKey(plugin.metadata.id)) {
      return;
    }

    final context = RuntimePluginContext(
      pluginId: plugin.metadata.id,
      runtime: runtime,
    );

    try {
      await plugin.activate(context);
      runtime.validator.validateOwner(plugin.metadata.id);
      _activePlugins[plugin.metadata.id] = plugin;
      _contexts[plugin.metadata.id] = context;
    } catch (_) {
      for (final target in runtime.cleanupTargets) {
        target.unregisterAllForOwner(plugin.metadata.id);
      }
      rethrow;
    }
  }

  Future<void> deactivate(String pluginId) async {
    final plugin = _activePlugins[pluginId];
    final context = _contexts[pluginId];
    if (plugin == null || context == null) return;

    // Phase 1: Close workbench views owned by this plugin
    runtime.workbench.removeViewsOwnedBy(pluginId);

    // Phase 2: Plugin deactivation logic
    await plugin.deactivate(context);

    // Phase 3: Cleanup all contributed items from registries
    for (final target in runtime.cleanupTargets) {
      target.unregisterAllForOwner(pluginId);
    }

    _activePlugins.remove(pluginId);
    _contexts.remove(pluginId);
  }

  List<AlhambraPlugin> get activePlugins => _activePlugins.values.toList();
}

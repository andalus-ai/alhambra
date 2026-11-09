import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../extensions/extension_runtime.dart';
import 'runtime_plugin_context.dart';

/// Manages the lifecycle of compiled, application-selected plugins.
///
/// The manager deliberately does not discover or execute Dart code. Hosts
/// construct the plugin instances they want to ship and pass them to this
/// manager.
class PluginManager {
  final Map<String, AlhambraPlugin> _activePlugins = {};
  final Map<String, RuntimePluginContext> _contexts = {};
  final ExtensionRuntime runtime;

  PluginManager({ExtensionRuntime? runtime})
      : runtime = runtime ?? ExtensionRuntime();

  /// Activates [plugin] once and rolls back its contributions on failure.
  Future<void> activate(AlhambraPlugin plugin) async {
    final pluginId = plugin.metadata.id;
    if (_activePlugins.containsKey(pluginId)) return;

    final context = RuntimePluginContext(
      pluginId: pluginId,
      runtime: runtime,
    );

    try {
      await plugin.activate(context);
      runtime.validator.validateOwner(pluginId);
      _activePlugins[pluginId] = plugin;
      _contexts[pluginId] = context;
    } catch (_) {
      _unregisterContributions(pluginId);
      rethrow;
    }
  }

  /// Deactivates a plugin and always releases host-owned resources.
  ///
  /// A plugin's [AlhambraPlugin.deactivate] hook may fail. That error is
  /// propagated to the caller, but it must not leave the plugin marked active
  /// or keep its contributions registered. This makes a subsequent activation
  /// attempt deterministic and prevents stale UI from surviving a failure.
  Future<void> deactivate(String pluginId) async {
    final plugin = _activePlugins[pluginId];
    final context = _contexts[pluginId];
    if (plugin == null || context == null) return;

    try {
      // Close workbench views before invoking plugin-owned shutdown logic.
      runtime.workbench.removeViewsOwnedBy(pluginId);
      await plugin.deactivate(context);
    } finally {
      // Cleanup and state removal must happen even when view removal or the
      // plugin's shutdown hook throws.
      try {
        _unregisterContributions(pluginId);
      } finally {
        _activePlugins.remove(pluginId);
        _contexts.remove(pluginId);
      }
    }
  }

  void _unregisterContributions(String pluginId) {
    for (final target in runtime.cleanupTargets) {
      target.unregisterAllForOwner(pluginId);
    }
  }

  /// A snapshot of the currently active compiled plugins.
  List<AlhambraPlugin> get activePlugins =>
      List<AlhambraPlugin>.unmodifiable(_activePlugins.values);
}

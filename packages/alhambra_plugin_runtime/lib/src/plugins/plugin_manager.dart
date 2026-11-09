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

  /// Per-plugin operation tails. Lifecycle work for different plugins remains
  /// independent, while operations for the same plugin are serialized.
  final Map<String, Future<void>> _operationTails = {};

  final ExtensionRuntime runtime;

  PluginManager({ExtensionRuntime? runtime})
      : runtime = runtime ?? ExtensionRuntime();

  /// Activates [plugin] once and rolls back its contributions on failure.
  Future<void> activate(AlhambraPlugin plugin) {
    final pluginId = plugin.metadata.id;
    if (pluginId.trim().isEmpty) {
      return Future<void>.error(
        ArgumentError.value(pluginId, 'plugin.metadata.id', 'Must not be empty'),
      );
    }

    return _serialize(pluginId, () async {
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
      } catch (error, stackTrace) {
        // A cleanup failure must not hide the activation error that caused
        // rollback. _unregisterContributions still attempts every registry.
        try {
          _unregisterContributions(pluginId);
        } catch (_) {
          // Preserve the original activation failure.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  /// Deactivates a plugin and always releases host-owned resources.
  ///
  /// If view removal, the plugin shutdown hook, or registry cleanup fails,
  /// the first failure is propagated after all cleanup targets have been
  /// attempted and the plugin has been removed from active state.
  Future<void> deactivate(String pluginId) {
    return _serialize(pluginId, () async {
      final plugin = _activePlugins[pluginId];
      final context = _contexts[pluginId];
      if (plugin == null || context == null) return;

      Object? failure;
      StackTrace? failureStackTrace;

      try {
        runtime.workbench.removeViewsOwnedBy(pluginId);
        await plugin.deactivate(context);
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
      }

      try {
        _unregisterContributions(pluginId);
      } catch (error, stackTrace) {
        failure ??= error;
        failureStackTrace ??= stackTrace;
      } finally {
        _activePlugins.remove(pluginId);
        _contexts.remove(pluginId);
      }

      if (failure != null) {
        Error.throwWithStackTrace(failure, failureStackTrace!);
      }
    });
  }

  Future<T> _serialize<T>(
    String pluginId,
    Future<T> Function() operation,
  ) async {
    final previous = _operationTails[pluginId] ?? Future<void>.value();
    final completer = Completer<void>();
    final tail = completer.future;
    _operationTails[pluginId] = tail;

    try {
      await previous;
      return await operation();
    } finally {
      completer.complete();
      if (identical(_operationTails[pluginId], tail)) {
        _operationTails.remove(pluginId);
      }
    }
  }

  void _unregisterContributions(String pluginId) {
    Object? firstFailure;
    StackTrace? firstFailureStackTrace;

    for (final target in runtime.cleanupTargets) {
      try {
        target.unregisterAllForOwner(pluginId);
      } catch (error, stackTrace) {
        firstFailure ??= error;
        firstFailureStackTrace ??= stackTrace;
      }
    }

    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure, firstFailureStackTrace!);
    }
  }

  /// A snapshot of the currently active compiled plugins.
  List<AlhambraPlugin> get activePlugins =>
      List<AlhambraPlugin>.unmodifiable(_activePlugins.values);
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_dependency_resolver.dart';
import 'plugin_loader.dart';
import 'plugin_manager.dart';

/// A plugin shutdown failure captured without aborting the remaining shutdown.
class PluginShutdownFailure {
  final String pluginId;
  final Object error;
  final StackTrace stackTrace;

  const PluginShutdownFailure({
    required this.pluginId,
    required this.error,
    required this.stackTrace,
  });
}

/// Immutable result of shutting down the plugins represented by a discovery
/// snapshot.
class PluginShutdownReport {
  /// False when dependency preflight failed or one or more plugins failed.
  final bool succeeded;

  /// Plugins for which shutdown was attempted, in reverse dependency order.
  final List<String> attemptedPluginIds;

  /// Plugins whose shutdown hooks and host cleanup completed successfully.
  final List<String> deactivatedPluginIds;

  /// Active plugins not represented by the supplied discovery snapshot.
  ///
  /// These are deliberately left untouched: callers may be shutting down only
  /// one application/plugin set while other sets share the same manager.
  final List<String> untouchedActivePluginIds;

  /// Failures collected while shutting down individual plugins.
  final List<PluginShutdownFailure> failures;

  /// A dependency/preflight error, when no shutdown attempt could safely begin.
  final Object? error;
  final StackTrace? stackTrace;

  const PluginShutdownReport({
    required this.succeeded,
    this.attemptedPluginIds = const [],
    this.deactivatedPluginIds = const [],
    this.untouchedActivePluginIds = const [],
    this.failures = const [],
    this.error,
    this.stackTrace,
  });
}

/// Coordinates plugin shutdown in reverse dependency order.
///
/// The supplied discovery snapshot defines the plugin set being shut down.
/// Plugins absent from that snapshot are not touched. Dependency validation is
/// completed before the first shutdown callback, so an invalid graph cannot
/// produce a partially shut-down set.
///
/// A failure from one plugin does not prevent later plugins in the shutdown
/// plan from being attempted. [PluginManager] remains the owner of individual
/// plugin lifecycle serialization and host-resource cleanup.
class PluginShutdownCoordinator {
  final PluginManager manager;
  final PluginDependencyResolver dependencyResolver;

  const PluginShutdownCoordinator({
    required this.manager,
    this.dependencyResolver = const PluginDependencyResolver(),
  });

  Future<PluginShutdownReport> shutdown({
    required Iterable<DiscoveredPlugin> discoveredPlugins,
  }) async {
    late final List<DiscoveredPlugin> shutdownPlan;
    late final Map<String, AlhambraPlugin> activeById;
    late final List<String> untouchedActiveIds;

    // Validate the complete dependency graph before invoking plugin code.
    try {
      shutdownPlan = PluginLoader.resolveDependencyOrder(
        discoveredPlugins,
        resolver: dependencyResolver,
      );

      activeById = <String, AlhambraPlugin>{};
      for (final plugin in manager.activePlugins) {
        final rawId = plugin.metadata.id;
        final id = rawId.trim();
        if (id.isEmpty) {
          throw PluginShutdownValidationException(
            'An active plugin has an empty ID.',
          );
        }
        if (activeById.containsKey(id)) {
          throw PluginShutdownValidationException(
            'Multiple active plugin instances resolve to ID "$id".',
            pluginId: id,
          );
        }
        activeById[id] = plugin;
      }

      final plannedIds = shutdownPlan
          .map((item) => item.manifest.id.trim())
          .toSet();
      untouchedActiveIds = activeById.keys
          .where((id) => !plannedIds.contains(id))
          .toList(growable: false);
    } catch (error, stackTrace) {
      return PluginShutdownReport(
        succeeded: false,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final attempted = <String>[];
    final deactivated = <String>[];
    final failures = <PluginShutdownFailure>[];

    for (final item in shutdownPlan.reversed) {
      final id = item.manifest.id.trim();
      final plugin = activeById[id];
      if (plugin == null) continue;

      attempted.add(id);
      try {
        // Use the plugin's original metadata ID because PluginManager keys
        // lifecycle state by that exact value.
        await manager.deactivate(plugin.metadata.id);
        deactivated.add(id);
      } catch (error, stackTrace) {
        failures.add(
          PluginShutdownFailure(
            pluginId: id,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    return PluginShutdownReport(
      succeeded: failures.isEmpty,
      attemptedPluginIds: List<String>.unmodifiable(attempted),
      deactivatedPluginIds: List<String>.unmodifiable(deactivated),
      untouchedActivePluginIds:
          List<String>.unmodifiable(untouchedActiveIds),
      failures: List<PluginShutdownFailure>.unmodifiable(failures),
    );
  }
}

/// A preflight error that prevents plugin shutdown from starting.
class PluginShutdownValidationException implements Exception {
  final String message;
  final String? pluginId;

  const PluginShutdownValidationException(this.message, {this.pluginId});

  @override
  String toString() => 'PluginShutdownValidationException: $message';
}

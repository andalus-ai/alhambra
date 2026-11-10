import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_dependency_resolver.dart';
import 'plugin_loader.dart';
import 'plugin_manager.dart';
import 'plugin_runtime_health.dart';

/// A failure while rolling back a partially-started plugin batch.
class PluginRollbackFailure {
  final String pluginId;
  final Object error;
  final StackTrace stackTrace;

  const PluginRollbackFailure({
    required this.pluginId,
    required this.error,
    required this.stackTrace,
  });
}

/// Immutable outcome of one transactional plugin startup attempt.
class PluginStartupBatchReport {
  /// Whether every plugin in the validated startup plan is active.
  final bool succeeded;

  /// The plugin whose activation failed, if activation was attempted.
  final String? failedPluginId;

  /// The original validation or activation failure.
  final Object? error;

  /// Stack trace for [error], when available.
  final StackTrace? stackTrace;

  /// Plugins activated by this batch, in activation order.
  final List<String> activatedPluginIds;

  /// Plugins successfully deactivated during rollback, in rollback order.
  final List<String> rolledBackPluginIds;

  /// Rollback failures. These never replace the original startup failure.
  final List<PluginRollbackFailure> rollbackFailures;

  const PluginStartupBatchReport({
    required this.succeeded,
    this.failedPluginId,
    this.error,
    this.stackTrace,
    this.activatedPluginIds = const [],
    this.rolledBackPluginIds = const [],
    this.rollbackFailures = const [],
  });
}

/// Starts a discovered plugin set as one best-effort transaction.
///
/// All manifests and compiled plugin instances are checked before the first
/// activation. Plugins are activated dependency-first. If activation fails,
/// only plugins activated by this invocation are deactivated, in reverse
/// order; plugins that were active before the invocation are left untouched.
///
/// This coordinator does not discover or execute downloaded Dart code.
class PluginStartupCoordinator {
  final PluginManager manager;
  final PluginDependencyResolver dependencyResolver;
  final PluginRuntimeHealthRegistry? healthRegistry;

  const PluginStartupCoordinator({
    required this.manager,
    this.dependencyResolver = const PluginDependencyResolver(),
    this.healthRegistry,
  });

  Future<PluginStartupBatchReport> start({
    required Iterable<DiscoveredPlugin> discoveredPlugins,
    required Map<String, AlhambraPlugin> compiledPlugins,
  }) async {
    late final List<DiscoveredPlugin> plan;
    late final Map<String, AlhambraPlugin> pluginsById;
    late final Set<String> previouslyActiveIds;

    // Preflight is deliberately completed before invoking any plugin code.
    try {
      final discovered = discoveredPlugins.toList(growable: false);
      plan = PluginLoader.resolveDependencyOrder(
        discovered,
        resolver: dependencyResolver,
      );

      pluginsById = <String, AlhambraPlugin>{};
      for (final item in plan) {
        final id = item.manifest.id.trim();
        final plugin = compiledPlugins[id];
        if (plugin == null) {
          throw PluginStartupValidationException(
            'No compiled plugin instance was supplied for manifest "$id".',
            pluginId: id,
          );
        }

        final runtimeId = plugin.metadata.id.trim();
        if (runtimeId != id) {
          throw PluginStartupValidationException(
            'Manifest ID "$id" does not match compiled plugin ID "$runtimeId".',
            pluginId: id,
          );
        }
        pluginsById[id] = plugin;
      }

      previouslyActiveIds = <String>{};
      for (final active in manager.activePlugins) {
        final id = active.metadata.id.trim();
        previouslyActiveIds.add(id);
        final requested = pluginsById[id];
        if (requested != null && !identical(active, requested)) {
          throw PluginStartupValidationException(
            'Plugin "$id" is already active with a different instance.',
            pluginId: id,
          );
        }
      }
    } catch (error, stackTrace) {
      return PluginStartupBatchReport(
        succeeded: false,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final health = healthRegistry;
    if (health != null) {
      for (final item in plan) {
        final id = item.manifest.id.trim();
        health.transition(
          pluginId: id,
          next: PluginRuntimeState.validated,
          reason: 'Startup preflight completed',
        );
      }
      for (final id in previouslyActiveIds) {
        health.observe(
          pluginId: id,
          state: PluginRuntimeState.active,
          reason: 'Already active before startup batch',
        );
      }
    }

    final activated = <AlhambraPlugin>[];

    for (final item in plan) {
      final id = item.manifest.id.trim();
      if (previouslyActiveIds.contains(id)) continue;

      final plugin = pluginsById[id]!;
      try {
        health?.transition(
          pluginId: id,
          next: PluginRuntimeState.starting,
          reason: 'Plugin activation started',
        );
        await manager.activate(plugin);
        activated.add(plugin);
        health?.transition(
          pluginId: id,
          next: PluginRuntimeState.active,
          reason: 'Plugin activation completed',
        );
      } catch (error, stackTrace) {
        health?.transition(
          pluginId: id,
          next: PluginRuntimeState.failed,
          reason: 'Plugin activation failed: $error',
        );
        final rolledBack = <String>[];
        final rollbackFailures = <PluginRollbackFailure>[];

        for (final started in activated.reversed) {
          final startedId = started.metadata.id.trim();
          try {
            health?.transition(
              pluginId: startedId,
              next: PluginRuntimeState.stopping,
              reason: 'Startup rollback started',
            );
            await manager.deactivate(startedId);
            health?.transition(
              pluginId: startedId,
              next: PluginRuntimeState.stopped,
              reason: 'Startup rollback completed',
            );
            rolledBack.add(startedId);
          } catch (rollbackError, rollbackStackTrace) {
            final snapshot = health?.snapshotOf(startedId);
            if (snapshot?.state == PluginRuntimeState.stopping) {
              health?.transition(
                pluginId: startedId,
                next: PluginRuntimeState.failed,
                reason: 'Startup rollback failed: $rollbackError',
              );
            }
            rollbackFailures.add(
              PluginRollbackFailure(
                pluginId: startedId,
                error: rollbackError,
                stackTrace: rollbackStackTrace,
              ),
            );
          }
        }

        return PluginStartupBatchReport(
          succeeded: false,
          failedPluginId: id,
          error: error,
          stackTrace: stackTrace,
          activatedPluginIds:
              List<String>.unmodifiable(activated.map((plugin) => plugin.metadata.id)),
          rolledBackPluginIds: List<String>.unmodifiable(rolledBack),
          rollbackFailures: List<PluginRollbackFailure>.unmodifiable(
            rollbackFailures,
          ),
        );
      }
    }

    return PluginStartupBatchReport(
      succeeded: true,
      activatedPluginIds: List<String>.unmodifiable(
        activated.map((plugin) => plugin.metadata.id),
      ),
    );
  }
}

/// A preflight validation failure. No plugin activation has started.
class PluginStartupValidationException implements Exception {
  final String message;
  final String? pluginId;

  const PluginStartupValidationException(this.message, {this.pluginId});

  @override
  String toString() => 'PluginStartupValidationException: $message';
}

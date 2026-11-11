import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_manager.dart';
import 'plugin_runtime_health.dart';

/// One correction made while aligning the health projection with live runtime.
class PluginRuntimeReconciliationChange {
  final String pluginId;
  final PluginRuntimeState? previousState;
  final PluginRuntimeState currentState;
  final String reason;

  const PluginRuntimeReconciliationChange({
    required this.pluginId,
    required this.previousState,
    required this.currentState,
    required this.reason,
  });
}

/// Immutable result of one reconciliation pass.
class PluginRuntimeReconciliationReport {
  final List<PluginRuntimeReconciliationChange> changes;
  final List<String> activePluginIds;
  final List<String> projectedPluginIds;

  const PluginRuntimeReconciliationReport({
    required this.changes,
    required this.activePluginIds,
    required this.projectedPluginIds,
  });

  bool get isConsistent => changes.isEmpty;
}

/// Repairs stale lifecycle projections using PluginManager as the authority.
///
/// The pass runs under the manager's lifecycle batch gate, so it cannot race
/// startup/shutdown coordinator batches. Hosts should use the coordinators for
/// lifecycle changes; direct manager calls are only serialized per plugin and
/// do not participate in the batch gate.
class PluginRuntimeReconciler {
  final PluginManager manager;
  final PluginRuntimeHealthRegistry registry;

  const PluginRuntimeReconciler({
    required this.manager,
    required this.registry,
  });

  Future<PluginRuntimeReconciliationReport> reconcile() {
    return manager.runExclusiveLifecycleBatch(_reconcile);
  }

  PluginRuntimeReconciliationReport _reconcile() {
    final activeById = <String, AlhambraPlugin>{};
    for (final plugin in manager.activePlugins) {
      final id = plugin.metadata.id.trim();
      if (id.isEmpty) {
        throw StateError('PluginManager contains an active plugin with an empty ID.');
      }
      if (activeById.containsKey(id)) {
        throw StateError('PluginManager contains duplicate active plugin ID "$id".');
      }
      activeById[id] = plugin;
    }

    final changes = <PluginRuntimeReconciliationChange>[];
    for (final id in activeById.keys) {
      final previous = registry.snapshotOf(id);
      if (previous?.state == PluginRuntimeState.active) continue;
      const reason = 'Reconciled: PluginManager reports plugin active';
      registry.synchronize(
        pluginId: id,
        state: PluginRuntimeState.active,
        reason: reason,
      );
      changes.add(PluginRuntimeReconciliationChange(
        pluginId: id,
        previousState: previous?.state,
        currentState: PluginRuntimeState.active,
        reason: reason,
      ));
    }

    for (final entry in registry.snapshots.entries.toList(growable: false)) {
      final id = entry.key;
      final state = entry.value.state;
      final mayBeStaleActive = state == PluginRuntimeState.active ||
          state == PluginRuntimeState.degraded ||
          state == PluginRuntimeState.starting ||
          state == PluginRuntimeState.stopping;
      if (activeById.containsKey(id) || !mayBeStaleActive) continue;
      const reason = 'Reconciled: PluginManager reports plugin inactive';
      registry.synchronize(
        pluginId: id,
        state: PluginRuntimeState.stopped,
        reason: reason,
      );
      changes.add(PluginRuntimeReconciliationChange(
        pluginId: id,
        previousState: state,
        currentState: PluginRuntimeState.stopped,
        reason: reason,
      ));
    }

    return PluginRuntimeReconciliationReport(
      changes: List.unmodifiable(changes),
      activePluginIds: List.unmodifiable(activeById.keys),
      projectedPluginIds: List.unmodifiable(registry.snapshots.keys),
    );
  }
}

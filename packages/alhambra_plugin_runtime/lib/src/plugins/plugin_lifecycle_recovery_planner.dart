import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_manager.dart';

/// Host action guidance inferred from a checkpoint and the live manager state.
///
/// These values are recommendations only. The planner never invokes plugin
/// hooks, changes checkpoints, or mutates PluginManager.
enum PluginLifecycleRecoveryDisposition {
  /// The last record is planned and this plugin is not active.
  notStarted,

  /// PluginManager confirms that the startup hook completed and the plugin is
  /// active, but the durable checkpoint stopped before the active record.
  startupActiveCheckpointStale,

  /// Startup was in progress at interruption and the plugin is not active.
  /// External side effects may still have happened.
  startupOutcomeAmbiguous,

  /// The plugin is active and the checkpoint agrees.
  consistentActive,

  /// The checkpoint says active but PluginManager does not.
  staleActiveCheckpoint,

  /// Shutdown was in progress but the plugin remains active.
  shutdownOutcomeAmbiguousActive,

  /// Shutdown was in progress and the plugin is no longer active.
  shutdownCompletedCheckpointStale,

  /// The checkpoint says stopped but PluginManager still reports active.
  stoppedCheckpointButActive,

  /// A failed startup/shutdown operation left the plugin active.
  failedButActive,

  /// The last operation failed and the plugin is not active.
  terminalFailure,

  /// Startup rollback is pending and the plugin is still active.
  rollbackRequired,

  /// Startup rollback is pending but the plugin is already inactive.
  rollbackCompletedCheckpointStale,

  /// Rollback failed while the plugin remains active.
  rollbackFailedButActive,

  /// Rollback failed, but PluginManager reports the plugin inactive.
  rollbackFailedButInactive,

  /// PluginManager reports an active plugin with no durable checkpoint.
  activeWithoutCheckpoint,

  /// A state not recognized by this planner needs host-specific handling.
  manualReview,
}

/// One read-only recovery finding for a plugin.
class PluginLifecycleRecoveryFinding {
  final String pluginId;
  final PluginLifecycleCheckpoint? checkpoint;
  final bool isActive;
  final PluginLifecycleRecoveryDisposition disposition;
  final String guidance;

  const PluginLifecycleRecoveryFinding({
    required this.pluginId,
    required this.checkpoint,
    required this.isActive,
    required this.disposition,
    required this.guidance,
  });

  bool get requiresHostAction =>
      disposition != PluginLifecycleRecoveryDisposition.consistentActive &&
      disposition != PluginLifecycleRecoveryDisposition.notStarted &&
      disposition != PluginLifecycleRecoveryDisposition.terminalFailure;
}

/// Immutable result of scanning durable checkpoints against live manager state.
class PluginLifecycleRecoveryReport {
  final DateTime inspectedAt;
  final List<PluginLifecycleRecoveryFinding> findings;

  PluginLifecycleRecoveryReport({
    required this.inspectedAt,
    required Iterable<PluginLifecycleRecoveryFinding> findings,
  }) : findings = List.unmodifiable(findings);

  List<PluginLifecycleRecoveryFinding> get requiringHostAction =>
      List.unmodifiable(findings.where((finding) => finding.requiresHostAction));

  bool get isConsistent => requiringHostAction.isEmpty;
}

/// Read-only scanner for interrupted plugin lifecycle operations.
///
/// Run this after the host has restored its durable checkpoint store and
/// reconstructed the set of compiled plugin instances. It compares records
/// with the manager's current active set while holding the same lifecycle batch
/// gate used by startup and shutdown coordinators.
class PluginLifecycleRecoveryPlanner {
  final PluginLifecycleCheckpointStore store;
  final PluginManager manager;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryPlanner({
    required this.store,
    required this.manager,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleRecoveryReport> inspect() {
    return manager.runExclusiveLifecycleBatch(_inspect);
  }

  Future<PluginLifecycleRecoveryReport> _inspect() async {
    final activeIds = <String>{};
    for (final plugin in manager.activePlugins) {
      final id = plugin.metadata.id.trim();
      if (id.isEmpty) {
        throw StateError('PluginManager contains an active plugin with an empty ID.');
      }
      if (!activeIds.add(id)) {
        throw StateError('PluginManager contains duplicate active plugin ID "$id".');
      }
    }

    final checkpoints = await store.readAll();
    final byId = <String, PluginLifecycleCheckpoint>{};
    for (final checkpoint in checkpoints) {
      final id = checkpoint.pluginId.trim();
      if (id.isEmpty) {
        throw StateError('Checkpoint store returned a record with an empty plugin ID.');
      }
      final existing = byId[id];
      if (existing != null) {
        throw StateError('Checkpoint store returned duplicate records for "$id".');
      }
      byId[id] = checkpoint;
    }

    final findings = <PluginLifecycleRecoveryFinding>[];
    for (final entry in byId.entries) {
      final checkpoint = entry.value;
      final active = activeIds.remove(entry.key) || false;
      final classified = _classify(checkpoint, active);
      findings.add(PluginLifecycleRecoveryFinding(
        pluginId: entry.key,
        checkpoint: checkpoint,
        isActive: active,
        disposition: classified.$1,
        guidance: classified.$2,
      ));
    }

    for (final id in activeIds) {
      findings.add(PluginLifecycleRecoveryFinding(
        pluginId: id,
        checkpoint: null,
        isActive: true,
        disposition: PluginLifecycleRecoveryDisposition.activeWithoutCheckpoint,
        guidance: 'Plugin is active but has no checkpoint. Verify its provenance '
            'and write a host-approved baseline before relying on recovery.',
      ));
    }

    findings.sort((a, b) => a.pluginId.compareTo(b.pluginId));
    return PluginLifecycleRecoveryReport(
      inspectedAt: _clock().toUtc(),
      findings: findings,
    );
  }

  (PluginLifecycleRecoveryDisposition, String) _classify(
    PluginLifecycleCheckpoint checkpoint,
    bool active,
  ) {
    switch (checkpoint.state) {
      case PluginLifecycleCheckpointState.planned:
        return active
            ? (PluginLifecycleRecoveryDisposition.stoppedCheckpointButActive,
                'The planned record precedes the plugin operation, but the plugin '
                'is active. Verify whether another lifecycle operation or process '
                'owns this activation before changing state.')
            : (PluginLifecycleRecoveryDisposition.notStarted,
                'No activation is visible in PluginManager. The planned operation '
                'did not reach a durable starting checkpoint; the host may safely '
                'revalidate the plan before starting a new operation.');

      case PluginLifecycleCheckpointState.starting:
        return active
            ? (PluginLifecycleRecoveryDisposition.startupActiveCheckpointStale,
                'PluginManager reports the plugin active. Verify its runtime and '
                'external side effects, then let the host persist an active '
                'checkpoint with a new operation ID.')
            : (PluginLifecycleRecoveryDisposition.startupOutcomeAmbiguous,
                'Activation was in progress at interruption. Inspect external '
                'side effects and plugin-specific idempotency/compensation before '
                'retrying, compensating, or marking failed.');

      case PluginLifecycleCheckpointState.active:
        return active
            ? (PluginLifecycleRecoveryDisposition.consistentActive,
                'Checkpoint and PluginManager agree that the plugin is active.')
            : (PluginLifecycleRecoveryDisposition.staleActiveCheckpoint,
                'Checkpoint says active but PluginManager does not. Reconcile the '
                'record to stopped only after confirming no external resources or '
                'side effects remain active.');

      case PluginLifecycleCheckpointState.stopping:
        return active
            ? (PluginLifecycleRecoveryDisposition.shutdownOutcomeAmbiguousActive,
                'Shutdown was in progress and the plugin remains active. Inspect '
                'partial teardown before deciding whether deactivation is safe to '
                'retry or compensation is required.')
            : (PluginLifecycleRecoveryDisposition.shutdownCompletedCheckpointStale,
                'PluginManager reports the plugin inactive. Verify external '
                'cleanup, then let the host finalize the checkpoint as stopped.');

      case PluginLifecycleCheckpointState.stopped:
        return active
            ? (PluginLifecycleRecoveryDisposition.stoppedCheckpointButActive,
                'Checkpoint says stopped while PluginManager reports active. '
                'Resolve ownership or a later activation before reconciling.')
            : (PluginLifecycleRecoveryDisposition.notStarted,
                'Checkpoint and PluginManager agree that the plugin is inactive.');

      case PluginLifecycleCheckpointState.failed:
        return active
            ? (PluginLifecycleRecoveryDisposition.failedButActive,
                'A lifecycle operation failed but the plugin remains active. '
                'Inspect health and side effects; do not assume failure cleaned '
                'up the plugin.')
            : (PluginLifecycleRecoveryDisposition.terminalFailure,
                'The operation failed and the plugin is inactive. Preserve failure '
                'details; a new attempt requires host policy and validation.');

      case PluginLifecycleCheckpointState.rollbackPending:
        return active
            ? (PluginLifecycleRecoveryDisposition.rollbackRequired,
                'Startup rollback is pending and the plugin remains active. '
                'Inspect plugin-specific compensation requirements before the '
                'host retries deactivation.')
            : (PluginLifecycleRecoveryDisposition.rollbackCompletedCheckpointStale,
                'PluginManager reports the plugin inactive. Verify external '
                'compensation, then let the host finalize rollback as stopped.');

      case PluginLifecycleCheckpointState.rollbackFailed:
        return active
            ? (PluginLifecycleRecoveryDisposition.rollbackFailedButActive,
                'Rollback failed and the plugin remains active. Escalate to host '
                'recovery policy; automatic retry is unsafe.')
            : (PluginLifecycleRecoveryDisposition.rollbackFailedButInactive,
                'Rollback reported failure but the plugin is inactive. Verify '
                'external resources and retain the rollback failure for audit.');

      case PluginLifecycleCheckpointState.interrupted:
        return (PluginLifecycleRecoveryDisposition.manualReview,
            'The checkpoint is explicitly marked interrupted. Apply host-specific '
            'recovery policy after inspecting live and external state.');
    }
  }
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_lifecycle_recovery_batch.dart';
import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_manager.dart';

/// One immutable, approval-ready recovery step.
final class PluginLifecycleRecoveryBatchPlanStep {
  final String pluginId;
  final int ordinal;
  final String expectedCheckpointOperationId;
  final int expectedCheckpointSequence;
  final String executionOperationId;
  final PluginLifecycleCheckpoint checkpoint;

  const PluginLifecycleRecoveryBatchPlanStep({
    required this.pluginId,
    required this.ordinal,
    required this.expectedCheckpointOperationId,
    required this.expectedCheckpointSequence,
    required this.executionOperationId,
    required this.checkpoint,
  });

  PluginRecoveryJobStep toJobStep() => PluginRecoveryJobStep(
        pluginId: pluginId,
        ordinal: ordinal,
        expectedCheckpointOperationId: expectedCheckpointOperationId,
        expectedCheckpointSequence: expectedCheckpointSequence,
        executionOperationId: executionOperationId,
      );
}

/// Read-only snapshot of a proposed recovery batch.
///
/// A plan is not authorization and does not reserve IDs in a global store.
/// The host must approve it, persist the resulting job, and let execution
/// revalidate every checkpoint and dependency before invoking plugin code.
final class PluginLifecycleRecoveryBatchPlan {
  final int schemaVersion;
  final PluginLifecycleRecoveryExecutionAction action;
  final List<String> orderedPluginIds;
  final List<PluginLifecycleRecoveryBatchPlanStep> steps;
  final List<String> blockers;
  final List<String> warnings;
  final DateTime plannedAt;

  PluginLifecycleRecoveryBatchPlan({
    this.schemaVersion = 1,
    required this.action,
    required Iterable<String> orderedPluginIds,
    required Iterable<PluginLifecycleRecoveryBatchPlanStep> steps,
    required Iterable<String> blockers,
    required Iterable<String> warnings,
    required DateTime plannedAt,
  })  : orderedPluginIds = List.unmodifiable(orderedPluginIds),
        steps = List.unmodifiable(steps),
        blockers = List.unmodifiable(blockers),
        warnings = List.unmodifiable(warnings),
        plannedAt = plannedAt.toUtc() {
    if (schemaVersion < 1) throw ArgumentError.value(schemaVersion, 'schemaVersion');
    if (this.steps.length != this.orderedPluginIds.length) {
      throw ArgumentError('A plan requires exactly one step per ordered plugin.');
    }
    for (var i = 0; i < this.steps.length; i++) {
      final step = this.steps[i];
      if (step.pluginId != this.orderedPluginIds[i] || step.ordinal != i) {
        throw ArgumentError('Plan steps must match ordered plugin IDs and ordinals.');
      }
    }
  }

  bool get isBlocked => blockers.isNotEmpty;
  bool get isExecutable => !isBlocked && steps.isNotEmpty;

  /// Builds the exact persisted intent after host approval.
  ///
  /// This method is pure: it does not write the job store or execute anything.
  PluginLifecycleRecoveryJob toJob({
    required String jobId,
    required String idempotencyKey,
    required String operationId,
    String? initiatedBy,
    String? correlationId,
  }) {
    if (!isExecutable) {
      throw StateError('A blocked or empty recovery plan cannot become a job.');
    }
    final jobAction = action == PluginLifecycleRecoveryExecutionAction.resumeStartup
        ? PluginRecoveryJobAction.resumeStartup
        : PluginRecoveryJobAction.compensateShutdown;
    return PluginLifecycleRecoveryJob.planned(
      jobId: jobId,
      idempotencyKey: idempotencyKey,
      operationId: operationId,
      action: jobAction,
      orderedPluginIds: orderedPluginIds,
      steps: steps.map((step) => step.toJobStep()),
      at: plannedAt,
      initiatedBy: initiatedBy,
      correlationId: correlationId,
    );
  }
}

/// Builds a deterministic recovery plan without changing runtime state.
///
/// The same checkpoint/dependency constraints are checked again by
/// [PluginLifecycleRecoveryRunner] at execution time. A plan is therefore a
/// review snapshot, never a lock or a promise that execution will still pass.
final class PluginLifecycleRecoveryBatchPlanner {
  final PluginLifecycleCheckpointStore store;
  final PluginManager manager;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryBatchPlanner({
    required this.store,
    required this.manager,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleRecoveryBatchPlan> planBatch(
    PluginLifecycleRecoveryBatchRequest request,
  ) {
    return manager.runExclusiveLifecycleBatch(
      () => planBatchWithinLifecycleBatch(request),
    );
  }

  /// Plans while the caller already owns [manager]'s lifecycle batch gate.
  /// Runtime coordinators use this to share preflight without nesting the gate.
  Future<PluginLifecycleRecoveryBatchPlan> planBatchWithinLifecycleBatch(
    PluginLifecycleRecoveryBatchRequest request,
  ) => _planBatch(request);

  Future<PluginLifecycleRecoveryBatchPlan> _planBatch(
    PluginLifecycleRecoveryBatchRequest request,
  ) async {
    final blockers = <String>[];
    final warnings = <String>[];
    final plannedAt = _clock().toUtc();
    final selected = <String>[];
    final selectedSet = <String>{};
    final checkpoints = <String, PluginLifecycleCheckpoint>{};
    final activeById = <String, AlhambraPlugin>{};
    var orderedIds = <String>[];

    try {
      for (final rawId in request.pluginIds) {
        final id = rawId.trim();
        if (id.isEmpty) {
          blockers.add('Plugin IDs must not be blank.');
        } else if (!selectedSet.add(id)) {
          blockers.add('Duplicate plugin ID "$id".');
        } else {
          selected.add(id);
        }
      }
      if (selected.isEmpty) blockers.add('Select at least one plugin.');

      for (final checkpoint in await store.readAll()) {
        final id = checkpoint.pluginId.trim();
        if (checkpoints.containsKey(id)) {
          blockers.add('Checkpoint store returned duplicate records for "$id".');
        } else {
          checkpoints[id] = checkpoint;
        }
      }

      for (final active in manager.activePlugins) {
        final id = active.metadata.id.trim();
        if (id.isEmpty || activeById.containsKey(id)) {
          blockers.add('PluginManager contains an invalid or duplicate active plugin ID "$id".');
        } else {
          activeById[id] = active;
        }
      }

      for (final id in selected) {
        final checkpoint = checkpoints[id];
        if (checkpoint == null) {
          blockers.add('No lifecycle checkpoint exists for "$id".');
          continue;
        }
        if (request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup) {
          final eligible = checkpoint.operation == PluginLifecycleOperation.startup &&
              (checkpoint.state == PluginLifecycleCheckpointState.planned ||
               checkpoint.state == PluginLifecycleCheckpointState.starting ||
               checkpoint.state == PluginLifecycleCheckpointState.interrupted);
          if (!eligible) blockers.add('"$id" has no incomplete startup checkpoint.');
          if (activeById.containsKey(id)) {
            blockers.add('"$id" is already active; reconcile its checkpoint before recovery.');
          }
          final compiled = request.compiledPlugins[id];
          if (compiled == null || compiled.metadata.id.trim() != id) {
            blockers.add('A matching compiled plugin instance is required for "$id".');
          }
          for (final rawDependency in checkpoint.dependencyIds) {
            final dependency = rawDependency.trim();
            if (!selectedSet.contains(dependency) && !activeById.containsKey(dependency)) {
              blockers.add('Startup recovery for "$id" requires inactive dependency "$dependency" outside this batch.');
            }
          }
        } else {
          final interruptedShutdown =
              checkpoint.operation == PluginLifecycleOperation.shutdown &&
              (checkpoint.state == PluginLifecycleCheckpointState.stopping ||
               checkpoint.state == PluginLifecycleCheckpointState.interrupted);
          final pendingRollback =
              checkpoint.operation == PluginLifecycleOperation.startup &&
              (checkpoint.state == PluginLifecycleCheckpointState.rollbackPending ||
               checkpoint.state == PluginLifecycleCheckpointState.rollbackFailed);
          if (!interruptedShutdown && !pendingRollback) {
            blockers.add('"$id" has no shutdown/rollback checkpoint eligible for compensation.');
          }
          if (!activeById.containsKey(id)) {
            blockers.add('"$id" is inactive; reconcile its checkpoint instead of compensating it.');
          }
          for (final other in activeById.keys) {
            if (other == id || selectedSet.contains(other)) continue;
            final dependentCheckpoint = checkpoints[other];
            if (dependentCheckpoint == null) {
              blockers.add('Cannot establish dependency order: active plugin "$other" has no checkpoint.');
            } else if (dependentCheckpoint.dependencyIds.any((dependency) => dependency.trim() == id)) {
              blockers.add('Active dependent "$other" must be included in this compensation batch.');
            }
          }
        }
      }

      if (blockers.isEmpty) {
        final indegree = <String, int>{for (final id in selected) id: 0};
        final dependents = <String, List<String>>{
          for (final id in selected) id: <String>[],
        };
        for (final id in selected) {
          for (final rawDependency in checkpoints[id]!.dependencyIds) {
            final dependency = rawDependency.trim();
            if (!selectedSet.contains(dependency)) continue;
            indegree[id] = indegree[id]! + 1;
            dependents[dependency]!.add(id);
          }
        }
        final ready = selected.where((id) => indegree[id] == 0).toList();
        final dependencyFirst = <String>[];
        while (ready.isNotEmpty) {
          final id = ready.removeAt(0);
          dependencyFirst.add(id);
          for (final dependent in dependents[id]!) {
            indegree[dependent] = indegree[dependent]! - 1;
            if (indegree[dependent] == 0) ready.add(dependent);
          }
        }
        if (dependencyFirst.length != selected.length) {
          blockers.add('Recovery batch dependency graph contains a cycle.');
        } else {
          orderedIds = request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup
              ? dependencyFirst
              : dependencyFirst.reversed.toList(growable: false);
        }
      }
    } catch (error) {
      blockers.add('Recovery preflight failed: ${error.runtimeType}.');
    }

    final steps = <PluginLifecycleRecoveryBatchPlanStep>[];
    if (blockers.isEmpty) {
      final uniqueOperationIds = <String>{};
      try {
        for (var index = 0; index < orderedIds.length; index++) {
          final id = orderedIds[index];
          final checkpoint = checkpoints[id]!;
          final operationId = request.operationIdFactory(id).trim();
          if (operationId.isEmpty || operationId == checkpoint.operationId) {
            blockers.add('Recovery operation ID for "$id" must be non-empty and differ from its checkpoint operation ID.');
            break;
          }
          if (!uniqueOperationIds.add(operationId)) {
            blockers.add('Recovery operation IDs must be unique within a batch.');
            break;
          }
          steps.add(PluginLifecycleRecoveryBatchPlanStep(
            pluginId: id,
            ordinal: index,
            expectedCheckpointOperationId: checkpoint.operationId,
            expectedCheckpointSequence: checkpoint.sequence,
            executionOperationId: operationId,
            checkpoint: checkpoint,
          ));
        }
      } catch (error) {
        blockers.add('Could not reserve recovery operation IDs: ${error.runtimeType}.');
      }
    }

    if (blockers.isEmpty) {
      warnings.add('This is a point-in-time plan; execution will revalidate checkpoints and dependencies.');
      warnings.add('Operation IDs are reserved in this plan only; the host must persist the resulting job before execution.');
    }

    return PluginLifecycleRecoveryBatchPlan(
      action: request.action,
      orderedPluginIds: blockers.isEmpty ? orderedIds : const [],
      steps: blockers.isEmpty ? steps : const [],
      blockers: blockers,
      warnings: warnings,
      plannedAt: plannedAt,
    );
  }
}

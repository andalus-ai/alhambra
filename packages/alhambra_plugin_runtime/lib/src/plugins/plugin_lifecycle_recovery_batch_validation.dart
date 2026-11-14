import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_lifecycle_recovery_batch.dart';
import 'plugin_lifecycle_recovery_batch_planner.dart';

/// Read-only result of checking an approval-ready plan against current state.
///
/// A current plan is still not an authorization token or an execution lock.
/// Hosts must persist the approved job and execution must revalidate again.
final class PluginLifecycleRecoveryBatchPlanValidation {
  final bool isCurrent;
  final List<String> blockers;
  final PluginLifecycleRecoveryBatchPlan? currentPlan;

  PluginLifecycleRecoveryBatchPlanValidation({
    required this.isCurrent,
    required Iterable<String> blockers,
    required this.currentPlan,
  }) : blockers = List<String>.unmodifiable(blockers);
}

/// Adds a pre-approval freshness check without changing the planner contract.
extension PluginLifecycleRecoveryBatchPlanValidationApi
    on PluginLifecycleRecoveryBatchPlanner {
  /// Rebuilds a plan using its already-reserved operation IDs and compares the
  /// complete checkpoint snapshots and execution order.
  ///
  /// No identifiers are regenerated, no store is written, and no plugin hook
  /// is invoked. The normal execution path must still revalidate later.
  Future<PluginLifecycleRecoveryBatchPlanValidation> validatePlan({
    required PluginLifecycleRecoveryBatchPlan plan,
    required PluginLifecycleRecoveryBatchRequest request,
  }) async {
    final blockers = <String>[];
    if (!plan.isExecutable) {
      blockers.add('Only an executable plan can be revalidated.');
      return PluginLifecycleRecoveryBatchPlanValidation(
        isCurrent: false,
        blockers: blockers,
        currentPlan: null,
      );
    }
    if (plan.action != request.action) {
      blockers.add('Recovery action differs from the reviewed plan.');
      return PluginLifecycleRecoveryBatchPlanValidation(
        isCurrent: false,
        blockers: blockers,
        currentPlan: null,
      );
    }

    final reservedIds = <String, String>{
      for (final step in plan.steps) step.pluginId: step.executionOperationId,
    };
    final current = await planBatch(PluginLifecycleRecoveryBatchRequest(
      pluginIds: request.pluginIds,
      action: request.action,
      compiledPlugins: request.compiledPlugins,
      operationIdFactory: (pluginId) {
        final id = reservedIds[pluginId];
        if (id == null) {
          throw StateError('Reviewed plan has no reserved operation ID for "$pluginId".');
        }
        return id;
      },
    ));

    if (!current.isExecutable) {
      blockers.addAll(current.blockers);
    } else {
      if (!_sameIds(plan.orderedPluginIds, current.orderedPluginIds)) {
        blockers.add('Dependency order changed since the plan was reviewed.');
      }
      if (plan.steps.length != current.steps.length) {
        blockers.add('Recovery target count changed since the plan was reviewed.');
      } else {
        for (var i = 0; i < plan.steps.length; i++) {
          final before = plan.steps[i];
          final now = current.steps[i];
          if (before.pluginId != now.pluginId ||
              before.ordinal != now.ordinal ||
              before.expectedCheckpointOperationId != now.expectedCheckpointOperationId ||
              before.expectedCheckpointSequence != now.expectedCheckpointSequence ||
              before.executionOperationId != now.executionOperationId ||
              !_sameCheckpoint(before.checkpoint, now.checkpoint)) {
            blockers.add('Recovery snapshot for "${before.pluginId}" changed since the plan was reviewed.');
          }
        }
      }
    }

    return PluginLifecycleRecoveryBatchPlanValidation(
      isCurrent: blockers.isEmpty,
      blockers: blockers,
      currentPlan: current,
    );
  }
}

bool _sameIds(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _sameCheckpoint(
  PluginLifecycleCheckpoint left,
  PluginLifecycleCheckpoint right,
) {
  return left.schemaVersion == right.schemaVersion &&
      left.pluginId == right.pluginId &&
      left.operationId == right.operationId &&
      left.operation == right.operation &&
      left.state == right.state &&
      left.sequence == right.sequence &&
      left.attempt == right.attempt &&
      left.createdAt == right.createdAt &&
      left.updatedAt == right.updatedAt &&
      left.failureCode == right.failureCode &&
      left.failureSummary == right.failureSummary &&
      _sameIds(left.dependencyIds, right.dependencyIds);
}

import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_plan.dart';
import 'composition_plan_diff.dart';

typedef CompositionReconcileActivator = FutureOr<void> Function(CompositionNode node);
typedef CompositionReconcileDeactivator = FutureOr<void> Function(CompositionNode node);

final class CompositionReconcileError {
  final String nodeId;
  final Object error;
  final StackTrace stackTrace;

  const CompositionReconcileError({
    required this.nodeId,
    required this.error,
    required this.stackTrace,
  });
}

final class CompositionReconcileResult {
  final bool succeeded;
  final CompositionPlanDiff diff;
  final List<String> activatedNodeIds;
  final List<String> deactivatedNodeIds;
  final String? failedNodeId;
  final Object? cause;
  final List<CompositionReconcileError> rollbackErrors;

  const CompositionReconcileResult._({
    required this.succeeded,
    required this.diff,
    required this.activatedNodeIds,
    required this.deactivatedNodeIds,
    this.failedNodeId,
    this.cause,
    this.rollbackErrors = const [],
  });

  factory CompositionReconcileResult.success({
    required CompositionPlanDiff diff,
    required List<String> activated,
    required List<String> deactivated,
  }) =>
      CompositionReconcileResult._(
        succeeded: true,
        diff: diff,
        activatedNodeIds: List.unmodifiable(activated),
        deactivatedNodeIds: List.unmodifiable(deactivated),
      );

  factory CompositionReconcileResult.failure({
    required CompositionPlanDiff diff,
    required List<String> activated,
    required List<String> deactivated,
    required String failedNodeId,
    required Object cause,
    required List<CompositionReconcileError> rollbackErrors,
  }) =>
      CompositionReconcileResult._(
        succeeded: false,
        diff: diff,
        activatedNodeIds: List.unmodifiable(activated),
        deactivatedNodeIds: List.unmodifiable(deactivated),
        failedNodeId: failedNodeId,
        cause: cause,
        rollbackErrors: List.unmodifiable(rollbackErrors),
      );
}

/// Applies a plan diff while preserving unchanged active nodes.
///
/// The operation is best-effort failure-atomic for external resources: on a
/// failed stop/start callback it attempts to restore the previous plan. Hosts
/// remain responsible for callbacks whose side effects cannot be reversed.
class CompositionReconciler {
  final CompositionReconcileActivator activateNode;
  final CompositionReconcileDeactivator deactivateNode;

  CompositionReconciler({
    required this.activateNode,
    required this.deactivateNode,
  });

  Future<CompositionReconcileResult> reconcile({
    required CompositionPlan current,
    required CompositionPlan desired,
  }) async {
    final diff = CompositionPlanDiff.between(current, desired);
    if (diff.isEmpty) {
      return CompositionReconcileResult.success(
        diff: diff,
        activated: const [],
        deactivated: const [],
      );
    }

    final stopIds = {
      ...diff.removed.map((node) => node.id),
      ...diff.replaced.map((node) => node.id),
    };
    final startIds = {
      ...diff.added.map((node) => node.id),
      ...diff.replaced.map((node) => node.id),
    };
    final stopOrder = current.activationOrder.reversed
        .where((node) => stopIds.contains(node.id))
        .toList(growable: false);
    final startOrder = desired.activationOrder
        .where((node) => startIds.contains(node.id))
        .toList(growable: false);

    final stopped = <CompositionNode>[];
    final started = <CompositionNode>[];

    Future<List<CompositionReconcileError>> restorePrevious() async {
      final errors = <CompositionReconcileError>[];
      // Remove newly started nodes first, in reverse dependency order.
      for (final node in started.reversed) {
        try {
          await Future<void>.sync(() => deactivateNode(node));
        } catch (error, stackTrace) {
          errors.add(CompositionReconcileError(
            nodeId: node.id,
            error: error,
            stackTrace: stackTrace,
          ));
        }
      }
      // Restore stopped old nodes provider-first.
      for (final node in stopped.reversed) {
        try {
          await Future<void>.sync(() => activateNode(node));
        } catch (error, stackTrace) {
          errors.add(CompositionReconcileError(
            nodeId: node.id,
            error: error,
            stackTrace: stackTrace,
          ));
        }
      }
      return errors;
    }

    for (final node in stopOrder) {
      try {
        await Future<void>.sync(() => deactivateNode(node));
        stopped.add(node);
      } catch (error, stackTrace) {
        final rollbackErrors = await restorePrevious();
        rollbackErrors.insert(
          0,
          CompositionReconcileError(
            nodeId: node.id,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        return CompositionReconcileResult.failure(
          diff: diff,
          activated: const [],
          deactivated: stopped.map((item) => item.id).toList(),
          failedNodeId: node.id,
          cause: error,
          rollbackErrors: rollbackErrors,
        );
      }
    }

    for (final node in startOrder) {
      try {
        await Future<void>.sync(() => activateNode(node));
        started.add(node);
      } catch (error, stackTrace) {
        final rollbackErrors = await restorePrevious();
        rollbackErrors.insert(
          0,
          CompositionReconcileError(
            nodeId: node.id,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        return CompositionReconcileResult.failure(
          diff: diff,
          activated: started.map((item) => item.id).toList(),
          deactivated: stopped.map((item) => item.id).toList(),
          failedNodeId: node.id,
          cause: error,
          rollbackErrors: rollbackErrors,
        );
      }
    }

    return CompositionReconcileResult.success(
      diff: diff,
      activated: started.map((node) => node.id).toList(),
      deactivated: stopped.map((node) => node.id).toList(),
    );
  }
}

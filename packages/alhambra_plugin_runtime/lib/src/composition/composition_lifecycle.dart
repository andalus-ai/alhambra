import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_plan.dart';

typedef CompositionNodeActivator = FutureOr<void> Function(CompositionNode node);
typedef CompositionNodeDeactivator = FutureOr<void> Function(CompositionNode node);

/// Retry configuration for an individual node activation.
///
/// [maxAttempts] includes the initial attempt. The predicate can be used to
/// avoid retrying permanent failures; it is evaluated after each failed attempt.
class CompositionRetryPolicy {
  final int maxAttempts;
  final bool Function(Object error, int failedAttempt)? shouldRetry;

  const CompositionRetryPolicy({
    this.maxAttempts = 1,
    this.shouldRetry,
  }) : assert(maxAttempts >= 1);

  bool permitsRetry(Object error, int failedAttempt) =>
      failedAttempt < maxAttempts &&
      (shouldRetry?.call(error, failedAttempt) ?? true);
}

final class CompositionLifecycleError {
  final String nodeId;
  final Object error;
  final StackTrace stackTrace;

  const CompositionLifecycleError({
    required this.nodeId,
    required this.error,
    required this.stackTrace,
  });
}

final class CompositionActivationResult {
  final bool succeeded;
  final List<String> activatedNodeIds;
  final String? failedNodeId;
  final Object? activationError;
  final List<CompositionLifecycleError> compensationErrors;

  const CompositionActivationResult._({
    required this.succeeded,
    required this.activatedNodeIds,
    this.failedNodeId,
    this.activationError,
    this.compensationErrors = const [],
  });

  factory CompositionActivationResult.success(List<String> activated) =>
      CompositionActivationResult._(
        succeeded: true,
        activatedNodeIds: List.unmodifiable(activated),
      );

  factory CompositionActivationResult.failure({
    required List<String> activated,
    required String failedNodeId,
    required Object error,
    required List<CompositionLifecycleError> compensationErrors,
  }) =>
      CompositionActivationResult._(
        succeeded: false,
        activatedNodeIds: List.unmodifiable(activated),
        failedNodeId: failedNodeId,
        activationError: error,
        compensationErrors: List.unmodifiable(compensationErrors),
      );
}

final class CompositionDeactivationResult {
  final List<String> deactivatedNodeIds;
  final List<CompositionLifecycleError> errors;

  const CompositionDeactivationResult({
    required this.deactivatedNodeIds,
    required this.errors,
  });

  bool get succeeded => errors.isEmpty;
}

/// Coordinates node lifecycle callbacks independently of any UI surface.
///
/// Activation follows the plan's dependency-first order. If a node fails,
/// previously activated nodes from this invocation are compensated in reverse
/// order. The coordinator owns lifecycle state, not graph membership.
class CompositionLifecycleCoordinator {
  final CompositionNodeActivator activateNode;
  final CompositionNodeDeactivator deactivateNode;
  final CompositionNodeDeactivator? compensateNode;
  final CompositionRetryPolicy retryPolicy;

  final Map<String, CompositionNodeState> _states = {};

  CompositionLifecycleCoordinator({
    required this.activateNode,
    required this.deactivateNode,
    this.compensateNode,
    this.retryPolicy = const CompositionRetryPolicy(),
  });

  Map<String, CompositionNodeState> get states => Map.unmodifiable(_states);

  CompositionNodeState stateOf(String nodeId) =>
      _states[nodeId] ?? CompositionNodeState.declared;

  Future<CompositionActivationResult> activate(CompositionPlan plan) async {
    final activatedThisRun = <CompositionNode>[];

    for (final node in plan.activationOrder) {
      if (stateOf(node.id) == CompositionNodeState.active) continue;
      _states[node.id] = CompositionNodeState.validated;
      _states[node.id] = CompositionNodeState.staged;

      Object? lastError;
      for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
        try {
          await Future<void>.sync(() => activateNode(node));
          _states[node.id] = CompositionNodeState.active;
          activatedThisRun.add(node);
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          _states[node.id] = CompositionNodeState.failed;
          if (!retryPolicy.permitsRetry(error, attempt)) break;
        }
      }

      if (lastError != null) {
        final compensationErrors = <CompositionLifecycleError>[];
        for (final activated in activatedThisRun.reversed) {
          try {
            final compensate = compensateNode ?? deactivateNode;
            await Future<void>.sync(() => compensate(activated));
            _states[activated.id] = CompositionNodeState.inactive;
          } catch (error, stackTrace) {
            _states[activated.id] = CompositionNodeState.failed;
            compensationErrors.add(CompositionLifecycleError(
              nodeId: activated.id,
              error: error,
              stackTrace: stackTrace,
            ));
          }
        }
        return CompositionActivationResult.failure(
          activated: activatedThisRun.map((node) => node.id).toList(),
          failedNodeId: node.id,
          error: lastError,
          compensationErrors: compensationErrors,
        );
      }
    }

    return CompositionActivationResult.success(
      activatedThisRun.map((node) => node.id).toList(),
    );
  }

  /// Deactivates active plan nodes in reverse dependency order.
  ///
  /// Failures are collected and do not prevent independent nodes from being
  /// deactivated. A failed deactivation leaves that node in [failed] state.
  Future<CompositionDeactivationResult> deactivate(CompositionPlan plan) async {
    final deactivated = <String>[];
    final errors = <CompositionLifecycleError>[];

    for (final node in plan.activationOrder.reversed) {
      if (stateOf(node.id) != CompositionNodeState.active) continue;
      try {
        await Future<void>.sync(() => deactivateNode(node));
        _states[node.id] = CompositionNodeState.inactive;
        deactivated.add(node.id);
      } catch (error, stackTrace) {
        _states[node.id] = CompositionNodeState.failed;
        errors.add(CompositionLifecycleError(
          nodeId: node.id,
          error: error,
          stackTrace: stackTrace,
        ));
      }
    }

    return CompositionDeactivationResult(
      deactivatedNodeIds: List.unmodifiable(deactivated),
      errors: List.unmodifiable(errors),
    );
  }

  /// Clears state for nodes no longer present in the supplied plan.
  ///
  /// This does not invoke lifecycle callbacks; callers should deactivate
  /// resources before reconciling state.
  void reconcile(CompositionPlan plan) {
    final currentIds = plan.nodes.keys.toSet();
    _states.removeWhere((id, _) => !currentIds.contains(id));
    for (final id in currentIds) {
      _states.putIfAbsent(id, () => CompositionNodeState.declared);
    }
  }
}

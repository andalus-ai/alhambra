import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_manager.dart';

/// Explicit host decision for reconciling a persisted lifecycle record.
enum PluginLifecycleRecoveryAction {
  /// The host verified that the plugin is active and accepts that state.
  acknowledgeActive,

  /// The host verified that the plugin and its owned resources are stopped.
  acknowledgeStopped,

  /// The host verified the operation cannot be accepted as successful.
  markFailed,
}

/// A stale-safe request to record an explicit recovery decision.
///
/// [expectedOperationId] and [expectedSequence] must match the latest durable
/// record observed by the caller. This prevents an old UI/job from knowingly
/// overwriting a newer checkpoint.
class PluginLifecycleRecoveryActionRequest {
  final String pluginId;
  final String expectedOperationId;
  final int expectedSequence;
  final PluginLifecycleRecoveryAction action;
  final String newOperationId;
  final String? failureCode;
  final String? failureSummary;

  const PluginLifecycleRecoveryActionRequest({
    required this.pluginId,
    required this.expectedOperationId,
    required this.expectedSequence,
    required this.action,
    required this.newOperationId,
    this.failureCode,
    this.failureSummary,
  });
}

/// Applies host-approved checkpoint decisions without invoking plugin hooks.
///
/// This controller is intentionally not a retry/compensation engine. Hosts
/// must perform and verify any external cleanup before acknowledging stopped.
class PluginLifecycleRecoveryController {
  final PluginLifecycleCheckpointStore store;
  final PluginManager manager;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryController({
    required this.store,
    required this.manager,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleCheckpoint> apply(
    PluginLifecycleRecoveryActionRequest request,
  ) {
    return manager.runExclusiveLifecycleBatch(() => _apply(request));
  }

  Future<PluginLifecycleCheckpoint> _apply(
    PluginLifecycleRecoveryActionRequest request,
  ) async {
    final pluginId = request.pluginId.trim();
    if (pluginId.isEmpty) {
      throw ArgumentError.value(request.pluginId, 'pluginId');
    }
    if (request.expectedOperationId.trim().isEmpty) {
      throw ArgumentError.value(request.expectedOperationId, 'expectedOperationId');
    }
    if (request.newOperationId.trim().isEmpty) {
      throw ArgumentError.value(request.newOperationId, 'newOperationId');
    }
    if (request.expectedSequence < 0) {
      throw ArgumentError.value(request.expectedSequence, 'expectedSequence');
    }
    if (request.newOperationId == request.expectedOperationId) {
      throw ArgumentError('Recovery decisions must use a new operation ID.');
    }

    final current = await store.read(pluginId);
    if (current == null) {
      throw StateError('No lifecycle checkpoint exists for "$pluginId".');
    }
    if (current.operationId != request.expectedOperationId ||
        current.sequence != request.expectedSequence) {
      throw StateError(
        'Checkpoint for "$pluginId" changed since it was inspected. '
        'Reload the recovery finding before applying an action.',
      );
    }

    final isActive = manager.activePlugins.any(
      (plugin) => plugin.metadata.id.trim() == pluginId,
    );

    late final PluginLifecycleCheckpointState nextState;
    switch (request.action) {
      case PluginLifecycleRecoveryAction.acknowledgeActive:
        if (!isActive) {
          throw StateError(
            'Cannot acknowledge "$pluginId" as active: PluginManager reports inactive.',
          );
        }
        nextState = PluginLifecycleCheckpointState.active;
        break;
      case PluginLifecycleRecoveryAction.acknowledgeStopped:
        if (isActive) {
          throw StateError(
            'Cannot acknowledge "$pluginId" as stopped: PluginManager reports active.',
          );
        }
        nextState = PluginLifecycleCheckpointState.stopped;
        break;
      case PluginLifecycleRecoveryAction.markFailed:
        if (isActive) {
          throw StateError(
            'Cannot mark "$pluginId" failed while PluginManager reports it active. '
            'Resolve or explicitly compensate the active plugin first.',
          );
        }
        nextState = PluginLifecycleCheckpointState.failed;
        break;
    }

    if (request.action == PluginLifecycleRecoveryAction.markFailed &&
        (request.failureSummary == null || request.failureSummary!.trim().isEmpty)) {
      throw ArgumentError('failureSummary is required when marking a lifecycle operation failed.');
    }

    final now = _clock().toUtc();
    final checkpoint = PluginLifecycleCheckpoint(
      schemaVersion: current.schemaVersion,
      pluginId: current.pluginId,
      operationId: request.newOperationId,
      operation: current.operation,
      state: nextState,
      sequence: current.sequence + 1,
      attempt: current.attempt,
      createdAt: current.createdAt,
      updatedAt: now.isBefore(current.updatedAt) ? current.updatedAt : now,
      dependencyIds: current.dependencyIds,
      failureCode: request.action == PluginLifecycleRecoveryAction.markFailed
          ? request.failureCode
          : null,
      failureSummary: request.action == PluginLifecycleRecoveryAction.markFailed
          ? request.failureSummary
          : null,
    );
    await store.write(checkpoint);
    return checkpoint;
  }
}

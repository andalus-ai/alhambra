import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_manager.dart';

enum PluginLifecycleRecoveryExecutionAction {
  resumeStartup,
  compensateShutdown,
}

class PluginLifecycleRecoveryExecutionRequest {
  final String pluginId;
  final String expectedOperationId;
  final int expectedSequence;
  final String newOperationId;
  final PluginLifecycleRecoveryExecutionAction action;

  const PluginLifecycleRecoveryExecutionRequest({
    required this.pluginId,
    required this.expectedOperationId,
    required this.expectedSequence,
    required this.newOperationId,
    required this.action,
  });
}

/// Host-visible context for one controlled recovery execution.
///
/// The host performs plugin-specific idempotency checks and external
/// preparation/compensation, then invokes exactly one matching lifecycle
/// method. Those methods delegate to PluginManager.
class PluginLifecycleRecoveryExecutionContext {
  final PluginLifecycleCheckpoint checkpoint;
  final AlhambraPlugin plugin;
  final PluginLifecycleRecoveryExecutionAction action;
  final Future<void> Function() _activate;
  final Future<void> Function() _deactivate;
  bool _lifecycleActionInvoked = false;

  PluginLifecycleRecoveryExecutionContext._({
    required this.checkpoint,
    required this.plugin,
    required this.action,
    required Future<void> Function() activate,
    required Future<void> Function() deactivate,
  })  : _activate = activate,
        _deactivate = deactivate;

  bool get lifecycleActionInvoked => _lifecycleActionInvoked;

  Future<void> resumeStartup() async {
    if (action != PluginLifecycleRecoveryExecutionAction.resumeStartup) {
      throw StateError('resumeStartup is not valid for this recovery action.');
    }
    _claimLifecycleAction();
    await _activate();
  }

  Future<void> compensateShutdown() async {
    if (action != PluginLifecycleRecoveryExecutionAction.compensateShutdown) {
      throw StateError('compensateShutdown is not valid for this recovery action.');
    }
    _claimLifecycleAction();
    await _deactivate();
  }

  void _claimLifecycleAction() {
    if (_lifecycleActionInvoked) {
      throw StateError('A recovery executor may invoke only one lifecycle action.');
    }
    _lifecycleActionInvoked = true;
  }
}

/// Host implementation for plugin-specific recovery policy and side effects.
///
/// Implementations should be idempotent, inspect external state before
/// repeating partially completed work, and avoid retaining secrets in errors.
abstract interface class PluginLifecycleRecoveryExecutor {
  Future<void> execute(PluginLifecycleRecoveryExecutionContext context);
}


/// Immutable request to recover a selected set of plugins as one dependency
/// ordered batch. The caller explicitly chooses the recovery targets.
class PluginLifecycleRecoveryBatchRequest {
  final List<String> pluginIds;
  final PluginLifecycleRecoveryExecutionAction action;
  final Map<String, AlhambraPlugin> compiledPlugins;
  final String Function(String pluginId) operationIdFactory;

  PluginLifecycleRecoveryBatchRequest({
    required Iterable<String> pluginIds,
    required this.action,
    this.compiledPlugins = const {},
    required this.operationIdFactory,
  }) : pluginIds = List<String>.unmodifiable(pluginIds);
}

/// Result of a dependency-ordered recovery batch.
///
/// A batch stops at its first execution failure. Completed plugin checkpoints
/// remain durable; the remaining IDs are returned for a later host decision.
class PluginLifecycleRecoveryBatchReport {
  final bool succeeded;
  final List<String> orderedPluginIds;
  final List<String> completedPluginIds;
  final List<String> skippedPluginIds;
  final String? failedPluginId;
  final Object? error;
  final StackTrace? stackTrace;

  PluginLifecycleRecoveryBatchReport({
    required this.succeeded,
    required Iterable<String> orderedPluginIds,
    Iterable<String> completedPluginIds = const [],
    Iterable<String> skippedPluginIds = const [],
    this.failedPluginId,
    this.error,
    this.stackTrace,
  })  : orderedPluginIds = List<String>.unmodifiable(orderedPluginIds),
        completedPluginIds = List<String>.unmodifiable(completedPluginIds),
        skippedPluginIds = List<String>.unmodifiable(skippedPluginIds);
}

/// Runs one explicitly requested recovery under the manager-wide lifecycle
/// gate. Hosts recover graphs dependency-first for startup and reverse
/// dependency order for shutdown/compensation.
class PluginLifecycleRecoveryRunner {
  final PluginLifecycleCheckpointStore store;
  final PluginManager manager;
  final PluginLifecycleRecoveryExecutor executor;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryRunner({
    required this.store,
    required this.manager,
    required this.executor,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleCheckpoint> execute(
    PluginLifecycleRecoveryExecutionRequest request, {
    AlhambraPlugin? compiledPlugin,
  }) {
    return manager.runExclusiveLifecycleBatch(
      () => _execute(request, compiledPlugin: compiledPlugin),
    );
  }


  /// Executes a selected recovery set in dependency-safe order.
  ///
  /// The complete checkpoint/dependency preflight and all plugin operations
  /// run under one manager-wide lifecycle gate. Startup is dependency-first;
  /// shutdown compensation is dependent-first. Execution stops at the first
  /// failure so a failed dependent is never followed by stopping its dependency.
  Future<PluginLifecycleRecoveryBatchReport> executeBatch(
    PluginLifecycleRecoveryBatchRequest request,
  ) {
    return manager.runExclusiveLifecycleBatch(() => _executeBatch(request));
  }

  Future<PluginLifecycleRecoveryBatchReport> _executeBatch(
    PluginLifecycleRecoveryBatchRequest request,
  ) async {
    late final List<String> orderedIds;
    late final Map<String, PluginLifecycleCheckpoint> checkpoints;
    try {
      final selected = <String>[];
      final selectedSet = <String>{};
      for (final rawId in request.pluginIds) {
        final id = rawId.trim();
        if (id.isEmpty) throw ArgumentError.value(rawId, 'pluginIds');
        if (!selectedSet.add(id)) {
          throw ArgumentError('Recovery batch contains duplicate plugin "$id".');
        }
        selected.add(id);
      }
      if (selected.isEmpty) {
        throw ArgumentError('Recovery batch must contain at least one plugin.');
      }

      final allCheckpoints = await store.readAll();
      checkpoints = <String, PluginLifecycleCheckpoint>{};
      for (final checkpoint in allCheckpoints) {
        final id = checkpoint.pluginId.trim();
        if (checkpoints.containsKey(id)) {
          throw StateError('Checkpoint store returned duplicate records for "$id".');
        }
        checkpoints[id] = checkpoint;
      }

      final activeById = <String, AlhambraPlugin>{};
      for (final active in manager.activePlugins) {
        final id = active.metadata.id.trim();
        if (id.isEmpty || activeById.containsKey(id)) {
          throw StateError('PluginManager contains an invalid or duplicate active plugin ID "$id".');
        }
        activeById[id] = active;
      }

      for (final id in selected) {
        final checkpoint = checkpoints[id];
        if (checkpoint == null) {
          throw StateError('No lifecycle checkpoint exists for "$id".');
        }
        if (request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup) {
          if (checkpoint.operation != PluginLifecycleOperation.startup ||
              (checkpoint.state != PluginLifecycleCheckpointState.planned &&
               checkpoint.state != PluginLifecycleCheckpointState.starting &&
               checkpoint.state != PluginLifecycleCheckpointState.interrupted)) {
            throw StateError('Plugin "$id" does not have an incomplete startup checkpoint.');
          }
          if (activeById.containsKey(id)) {
            throw StateError('Plugin "$id" is already active; reconcile its checkpoint before recovery.');
          }
          final compiled = request.compiledPlugins[id];
          if (compiled == null || compiled.metadata.id.trim() != id) {
            throw ArgumentError('A matching compiled plugin instance is required for "$id".');
          }
          for (final dependencyId in checkpoint.dependencyIds) {
            final dependency = dependencyId.trim();
            if (!selectedSet.contains(dependency) && !activeById.containsKey(dependency)) {
              throw StateError('Startup recovery for "$id" requires inactive dependency "$dependency" outside this batch.');
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
            throw StateError('Plugin "$id" does not have a shutdown/rollback checkpoint eligible for compensation.');
          }
          if (!activeById.containsKey(id)) {
            throw StateError('Plugin "$id" is inactive; reconcile its checkpoint instead of compensating it.');
          }
          for (final other in activeById.keys) {
            if (other == id || selectedSet.contains(other)) continue;
            final dependentCheckpoint = checkpoints[other];
            if (dependentCheckpoint == null) {
              throw StateError('Cannot establish dependency order: active plugin "$other" has no checkpoint.');
            }
            if (dependentCheckpoint.dependencyIds.any((dependency) => dependency.trim() == id)) {
              throw StateError('Active dependent "$other" must be included in this shutdown compensation batch.');
            }
          }
        }
      }

      // Stable Kahn topological sort. Dependency edges point from prerequisite
      // to dependent; reverse the result for shutdown compensation.
      final indegree = <String, int>{for (final id in selected) id: 0};
      final dependents = <String, List<String>>{
        for (final id in selected) id: <String>[],
      };
      for (final id in selected) {
        for (final dependencyId in checkpoints[id]!.dependencyIds) {
          final dependency = dependencyId.trim();
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
        throw StateError('Recovery batch dependency graph contains a cycle.');
      }
      orderedIds = request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup
          ? dependencyFirst
          : dependencyFirst.reversed.toList(growable: false);
    } catch (error, stackTrace) {
      return PluginLifecycleRecoveryBatchReport(
        succeeded: false,
        orderedPluginIds: const [],
        error: error,
        stackTrace: stackTrace,
      );
    }

    final completed = <String>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final id = orderedIds[index];
      final checkpoint = checkpoints[id]!;
      try {
        final operationId = request.operationIdFactory(id).trim();
        if (operationId.isEmpty || operationId == checkpoint.operationId) {
          throw ArgumentError('Recovery operation ID for "$id" must be non-empty and differ from the checkpoint operation ID.');
        }
        if (completed.any((completedId) =>
            request.operationIdFactory(completedId).trim() == operationId)) {
          throw ArgumentError('Recovery operation IDs must be unique within a batch.');
        }
        await _execute(
          PluginLifecycleRecoveryExecutionRequest(
            pluginId: id,
            expectedOperationId: checkpoint.operationId,
            expectedSequence: checkpoint.sequence,
            newOperationId: operationId,
            action: request.action,
          ),
          compiledPlugin: request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup
              ? request.compiledPlugins[id]
              : null,
        );
        completed.add(id);
      } catch (error, stackTrace) {
        return PluginLifecycleRecoveryBatchReport(
          succeeded: false,
          orderedPluginIds: orderedIds,
          completedPluginIds: completed,
          skippedPluginIds: orderedIds.skip(index + 1),
          failedPluginId: id,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return PluginLifecycleRecoveryBatchReport(
      succeeded: true,
      orderedPluginIds: orderedIds,
      completedPluginIds: completed,
    );
  }

  Future<PluginLifecycleCheckpoint> _execute(
    PluginLifecycleRecoveryExecutionRequest request, {
    required AlhambraPlugin? compiledPlugin,
  }) async {
    final pluginId = request.pluginId.trim();
    if (pluginId.isEmpty) throw ArgumentError.value(request.pluginId, 'pluginId');
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
      throw ArgumentError('Recovery execution must use a new operation ID.');
    }

    final current = await store.read(pluginId);
    if (current == null) throw StateError('No lifecycle checkpoint exists for "$pluginId".');
    if (current.operationId != request.expectedOperationId ||
        current.sequence != request.expectedSequence) {
      throw StateError('Checkpoint for "$pluginId" changed; inspect recovery again.');
    }

    final activeById = <String, AlhambraPlugin>{
      for (final active in manager.activePlugins) active.metadata.id.trim(): active,
    };
    final activePlugin = activeById[pluginId];
    late final AlhambraPlugin plugin;
    late final PluginLifecycleCheckpointState inFlightState;
    late final PluginLifecycleCheckpointState completedState;
    late final PluginLifecycleOperation operation;

    switch (request.action) {
      case PluginLifecycleRecoveryExecutionAction.resumeStartup:
        if (current.operation != PluginLifecycleOperation.startup ||
            (current.state != PluginLifecycleCheckpointState.planned &&
             current.state != PluginLifecycleCheckpointState.starting &&
             current.state != PluginLifecycleCheckpointState.interrupted)) {
          throw StateError('Only an incomplete startup checkpoint can be resumed.');
        }
        if (activePlugin != null) {
          throw StateError('Cannot resume "$pluginId": PluginManager already reports it active.');
        }
        final supplied = compiledPlugin;
        if (supplied == null || supplied.metadata.id.trim() != pluginId) {
          throw ArgumentError('A matching compiled plugin instance is required to resume startup.');
        }
        for (final dependencyId in current.dependencyIds) {
          if (!activeById.containsKey(dependencyId.trim())) {
            throw StateError('Cannot resume "$pluginId": dependency "$dependencyId" is not active.');
          }
        }
        plugin = supplied;
        inFlightState = PluginLifecycleCheckpointState.starting;
        completedState = PluginLifecycleCheckpointState.active;
        operation = PluginLifecycleOperation.startup;
        break;

      case PluginLifecycleRecoveryExecutionAction.compensateShutdown:
        final interruptedShutdown =
            current.operation == PluginLifecycleOperation.shutdown &&
            (current.state == PluginLifecycleCheckpointState.stopping ||
             current.state == PluginLifecycleCheckpointState.interrupted);
        final pendingRollback =
            current.operation == PluginLifecycleOperation.startup &&
            (current.state == PluginLifecycleCheckpointState.rollbackPending ||
             current.state == PluginLifecycleCheckpointState.rollbackFailed);
        if (!interruptedShutdown && !pendingRollback) {
          throw StateError('Checkpoint is not eligible for shutdown compensation.');
        }
        final active = activePlugin;
        if (active == null) {
          throw StateError('Cannot compensate "$pluginId": PluginManager reports it inactive.');
        }
        for (final other in activeById.entries) {
          if (other.key == pluginId) continue;
          final dependentCheckpoint = await store.read(other.key);
          if (dependentCheckpoint == null) {
            throw StateError(
              'Cannot establish dependency order for active plugin "${other.key}": '
              'its checkpoint is missing.',
            );
          }
          if (dependentCheckpoint.dependencyIds.any((id) => id.trim() == pluginId)) {
            throw StateError('Cannot compensate "$pluginId": active dependent "${other.key}" must stop first.');
          }
        }
        plugin = active;
        inFlightState = PluginLifecycleCheckpointState.stopping;
        completedState = PluginLifecycleCheckpointState.stopped;
        operation = current.operation;
        break;
    }

    final inFlight = _nextCheckpoint(
      current,
      operationId: request.newOperationId,
      operation: operation,
      state: inFlightState,
      sequence: current.sequence + 1,
      attempt: current.attempt + 1,
      updatedAt: _nextTimestamp(current.updatedAt),
    );
    await store.write(inFlight);

    final context = PluginLifecycleRecoveryExecutionContext._(
      checkpoint: inFlight,
      plugin: plugin,
      action: request.action,
      activate: () => manager.activate(plugin),
      deactivate: () => manager.deactivate(plugin.metadata.id),
    );

    try {
      await executor.execute(context);
      if (!context.lifecycleActionInvoked) {
        throw StateError('Recovery executor returned without invoking its lifecycle action.');
      }
      final isActive = manager.activePlugins.any((item) => item.metadata.id.trim() == pluginId);
      final expectedActive = request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup;
      if (isActive != expectedActive) {
        throw StateError('Recovery executor completed but PluginManager state did not match the requested outcome.');
      }
      final completed = _nextCheckpoint(
        inFlight,
        operationId: request.newOperationId,
        operation: operation,
        state: completedState,
        sequence: inFlight.sequence + 1,
        attempt: inFlight.attempt,
        updatedAt: _nextTimestamp(inFlight.updatedAt),
      );
      await store.write(completed);
      return completed;
    } catch (error) {
      try {
        await store.write(_nextCheckpoint(
          inFlight,
          operationId: request.newOperationId,
          operation: operation,
          state: PluginLifecycleCheckpointState.failed,
          sequence: inFlight.sequence + 1,
          attempt: inFlight.attempt,
          updatedAt: _nextTimestamp(inFlight.updatedAt),
          failureCode: error.runtimeType.toString(),
          failureSummary: 'Host-controlled lifecycle recovery failed',
        ));
      } catch (_) {
        // Preserve the execution error; the in-flight checkpoint remains a
        // recovery signal if the failure checkpoint cannot be persisted.
      }
      rethrow;
    }
  }

  DateTime _nextTimestamp(DateTime previous) {
    final now = _clock().toUtc();
    return now.isBefore(previous) ? previous : now;
  }

  PluginLifecycleCheckpoint _nextCheckpoint(
    PluginLifecycleCheckpoint previous, {
    required String operationId,
    required PluginLifecycleOperation operation,
    required PluginLifecycleCheckpointState state,
    required int sequence,
    required int attempt,
    required DateTime updatedAt,
    String? failureCode,
    String? failureSummary,
  }) => PluginLifecycleCheckpoint(
    schemaVersion: previous.schemaVersion,
    pluginId: previous.pluginId,
    operationId: operationId,
    operation: operation,
    state: state,
    sequence: sequence,
    attempt: attempt,
    createdAt: previous.createdAt,
    updatedAt: updatedAt,
    dependencyIds: previous.dependencyIds,
    failureCode: failureCode,
    failureSummary: failureSummary,
  );
}

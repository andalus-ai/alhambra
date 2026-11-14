import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_batch_planner.dart';
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

  /// Executes a pre-authorized recovery job while durably claiming and
  /// recording each step. The job's ordered targets, checkpoint snapshots,
  /// and execution operation IDs must match the freshly validated batch.
  ///
  /// A step is claimed before plugin code runs. If outcome persistence fails
  /// after a side effect, its durable status remains running for host review;
  /// this method never retries an ambiguous step.
  Future<PluginLifecycleRecoveryBatchReport> executeBatchWithJob({
    required PluginLifecycleRecoveryBatchRequest request,
    required PluginLifecycleRecoveryJobStore jobStore,
    required String jobId,
  }) {
    return manager.runExclusiveLifecycleBatch(
      () => _executeBatch(request, jobStore: jobStore, jobId: jobId),
    );
  }

  Future<PluginLifecycleRecoveryBatchReport> _executeBatch(
    PluginLifecycleRecoveryBatchRequest request, {
    PluginLifecycleRecoveryJobStore? jobStore,
    String? jobId,
  }) async {
    final plan = await PluginLifecycleRecoveryBatchPlanner(
      store: store,
      manager: manager,
      clock: _clock,
    ).planBatchWithinLifecycleBatch(request);
    if (!plan.isExecutable) {
      return PluginLifecycleRecoveryBatchReport(
        succeeded: false,
        orderedPluginIds: plan.orderedPluginIds,
        error: StateError(plan.blockers.join(' ')),
      );
    }
    final orderedIds = plan.orderedPluginIds;
    final checkpoints = <String, PluginLifecycleCheckpoint>{
      for (final step in plan.steps) step.pluginId: step.checkpoint,
    };
    final operationIds = <String, String>{
      for (final step in plan.steps) step.pluginId: step.executionOperationId,
    };

    PluginLifecycleRecoveryJob? journal;
    if (jobStore != null) {
      try {
        if (jobId == null || jobId.trim().isEmpty) {
          throw ArgumentError.value(jobId, 'jobId');
        }
        journal = await jobStore.read(jobId);
        if (journal == null) throw StateError('Recovery job "$jobId" does not exist.');
        final expectedAction = request.action == PluginLifecycleRecoveryExecutionAction.resumeStartup
            ? PluginRecoveryJobAction.resumeStartup
            : PluginRecoveryJobAction.compensateShutdown;
        if (journal.status != PluginRecoveryJobStatus.planned ||
            journal.action != expectedAction ||
            !_sameIds(journal.orderedPluginIds, orderedIds)) {
          throw StateError('Recovery job is not planned for this exact action and dependency order.');
        }
        for (var i = 0; i < orderedIds.length; i++) {
          final id = orderedIds[i];
          final step = journal.steps[i];
          final checkpoint = checkpoints[id]!;
          if (step.status != PluginRecoveryJobStepStatus.pending ||
              step.expectedCheckpointOperationId != checkpoint.operationId ||
              step.expectedCheckpointSequence != checkpoint.sequence ||
              step.executionOperationId == null ||
              step.executionOperationId!.trim().isEmpty ||
              step.executionOperationId != operationIds[id]) {
            throw StateError('Recovery job step for "$id" is stale, incomplete, or has a different execution operation ID.');
          }
        }
        final runningJob = journal.next(
          status: PluginRecoveryJobStatus.running,
          at: _clock().toUtc(),
          steps: journal.steps,
        );
        if (!await jobStore.compareAndSet(
          jobId: journal.jobId,
          expectedRevision: journal.revision,
          replacement: runningJob,
        )) {
          throw StateError('Recovery job changed before execution could be claimed.');
        }
        journal = runningJob;
      } catch (error, stackTrace) {
        return PluginLifecycleRecoveryBatchReport(
          succeeded: false,
          orderedPluginIds: orderedIds,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final completed = <String>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final id = orderedIds[index];
      final checkpoint = checkpoints[id]!;
      if (journal != null) {
        final currentJob = journal;
        final currentStep = currentJob!.steps[index];
        final claimedAt = _clock().toUtc();
        final claimedStep = currentStep.copyWith(
          status: PluginRecoveryJobStepStatus.running,
          startedAt: claimedAt,
          executionOperationId: operationIds[id],
        );
        final claimedSteps = currentJob.steps.toList(growable: false);
        final mutableClaimedSteps = claimedSteps.toList();
        mutableClaimedSteps[index] = claimedStep;
        final claimedJob = currentJob.next(
          status: PluginRecoveryJobStatus.running,
          at: claimedAt,
          steps: mutableClaimedSteps,
        );
        try {
          if (!await jobStore!.compareAndSet(
            jobId: currentJob.jobId,
            expectedRevision: currentJob.revision,
            replacement: claimedJob,
          )) {
            throw StateError('Could not claim recovery step "$id"; job revision changed.');
          }
          journal = claimedJob;
        } catch (error, stackTrace) {
          return PluginLifecycleRecoveryBatchReport(
            succeeded: false,
            orderedPluginIds: orderedIds,
            completedPluginIds: completed,
            skippedPluginIds: orderedIds.skip(index),
            failedPluginId: id,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      try {
        final operationId = operationIds[id]!;
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
      } catch (error, stackTrace) {
        if (journal != null) {
          final currentJob = journal!;
          try {
            final now = _clock().toUtc();
            final updatedSteps = currentJob.steps.toList();
            updatedSteps[index] = updatedSteps[index].copyWith(
              status: PluginRecoveryJobStepStatus.failed,
              completedAt: now,
              failureCode: error.runtimeType.toString(),
              failureSummary: 'Plugin recovery step failed; inspect lifecycle and external state',
            );
            final failedJob = currentJob.next(
              status: completed.isEmpty
                  ? PluginRecoveryJobStatus.failed
                  : PluginRecoveryJobStatus.partiallyCompleted,
              at: now,
              steps: updatedSteps,
              failureCode: error.runtimeType.toString(),
              failureSummary: 'Recovery batch stopped after a plugin step failed',
            );
            if (await jobStore!.compareAndSet(
              jobId: currentJob.jobId,
              expectedRevision: currentJob.revision,
              replacement: failedJob,
            )) {
              journal = failedJob;
            }
          } catch (_) {
            // Leave the durable running claim intact. Restart inspection must
            // treat it as ambiguous instead of assuming the failure was saved.
          }
        }
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

      // Deliberately outside the execution catch: if the plugin side effect
      // succeeded but this write fails, retain the running claim for inspection.
      if (journal != null) {
        final currentJob = journal!;
        final now = _clock().toUtc();
        final updatedSteps = currentJob.steps.toList();
        updatedSteps[index] = updatedSteps[index].copyWith(
          status: PluginRecoveryJobStepStatus.completed,
          completedAt: now,
        );
        final updatedJob = currentJob.next(
          status: PluginRecoveryJobStatus.running,
          at: now,
          steps: updatedSteps,
        );
        try {
          if (!await jobStore!.compareAndSet(
            jobId: currentJob.jobId,
            expectedRevision: currentJob.revision,
            replacement: updatedJob,
          )) {
            throw StateError('Plugin "$id" completed but its job outcome could not be persisted; inspect before retrying.');
          }
          journal = updatedJob;
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
      completed.add(id);
    }

    if (journal != null) {
      final currentJob = journal!;
      final completedJob = currentJob.next(
        status: PluginRecoveryJobStatus.completed,
        at: _clock().toUtc(),
        steps: currentJob.steps,
      );
      try {
        if (!await jobStore!.compareAndSet(
          jobId: currentJob.jobId,
          expectedRevision: currentJob.revision,
          replacement: completedJob,
        )) {
          throw StateError('All plugin steps completed but the final job status could not be persisted.');
        }
        journal = completedJob;
      } catch (error, stackTrace) {
        return PluginLifecycleRecoveryBatchReport(
          succeeded: false,
          orderedPluginIds: orderedIds,
          completedPluginIds: completed,
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


bool _sameIds(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

import 'plugin_lifecycle_checkpoint.dart';
import 'plugin_lifecycle_recovery_job.dart';

enum PluginRecoveryJobStepDisposition {
  pending,
  completedAndVerified,
  runningNeedsInspection,
  failedNeedsDecision,
  skippedNeedsDecision,
  checkpointMissing,
  checkpointChanged,
  activeStateMismatch,
}

final class PluginRecoveryJobStepFinding {
  final String pluginId;
  final int ordinal;
  final PluginRecoveryJobStepDisposition disposition;
  final String guidance;

  const PluginRecoveryJobStepFinding({
    required this.pluginId,
    required this.ordinal,
    required this.disposition,
    required this.guidance,
  });
}

enum PluginRecoveryJobDisposition {
  readyToStart,
  completed,
  interruptedNeedsInspection,
  failedNeedsDecision,
  inconsistent,
  cancelled,
}

final class PluginRecoveryJobRecoveryReport {
  final String jobId;
  final PluginRecoveryJobDisposition disposition;
  final List<PluginRecoveryJobStepFinding> steps;
  final List<String> activePluginIds;

  PluginRecoveryJobRecoveryReport({
    required this.jobId,
    required this.disposition,
    required Iterable<PluginRecoveryJobStepFinding> steps,
    required Iterable<String> activePluginIds,
  })  : steps = List.unmodifiable(steps),
        activePluginIds = List.unmodifiable(activePluginIds);

  bool get requiresHostAction => disposition != PluginRecoveryJobDisposition.completed &&
      disposition != PluginRecoveryJobDisposition.readyToStart;
}

/// Read-only restart inspection. It never changes jobs/checkpoints or invokes
/// plugin code; ambiguous in-flight steps are surfaced for explicit host review.
final class PluginLifecycleRecoveryJobPlanner {
  final PluginLifecycleRecoveryJobStore jobStore;
  final PluginLifecycleCheckpointStore checkpointStore;

  const PluginLifecycleRecoveryJobPlanner({
    required this.jobStore,
    required this.checkpointStore,
  });

  Future<PluginRecoveryJobRecoveryReport> inspect({
    required String jobId,
    required Iterable<String> activePluginIds,
  }) async {
    final job = await jobStore.read(jobId);
    if (job == null) throw StateError('Recovery job "$jobId" does not exist.');
    final checkpoints = <String, PluginLifecycleCheckpoint>{
      for (final checkpoint in await checkpointStore.readAll())
        checkpoint.pluginId: checkpoint,
    };
    final active = activePluginIds.map((id) => id.trim()).toSet();
    final findings = <PluginRecoveryJobStepFinding>[];

    for (final step in job.steps) {
      final checkpoint = checkpoints[step.pluginId];
      late final PluginRecoveryJobStepDisposition disposition;
      late final String guidance;

      if (step.status == PluginRecoveryJobStepStatus.completed) {
        final expectedState = job.action == PluginRecoveryJobAction.resumeStartup
            ? PluginLifecycleCheckpointState.active
            : PluginLifecycleCheckpointState.stopped;
        final isActive = active.contains(step.pluginId);
        final stateMatches = job.action == PluginRecoveryJobAction.resumeStartup
            ? isActive
            : !isActive;
        if (checkpoint != null &&
            checkpoint.operationId == step.executionOperationId &&
            checkpoint.state == expectedState &&
            stateMatches) {
          disposition = PluginRecoveryJobStepDisposition.completedAndVerified;
          guidance = 'Completed checkpoint and live manager state agree.';
        } else {
          disposition = PluginRecoveryJobStepDisposition.activeStateMismatch;
          guidance = 'Completed step no longer matches its checkpoint or live manager state; inspect before changing the job.';
        }
      } else if (step.status == PluginRecoveryJobStepStatus.running) {
        disposition = PluginRecoveryJobStepDisposition.runningNeedsInspection;
        guidance = 'The process may have stopped during a side effect. Inspect external state; do not replay automatically.';
      } else if (step.status == PluginRecoveryJobStepStatus.failed) {
        disposition = PluginRecoveryJobStepDisposition.failedNeedsDecision;
        guidance = 'A prior attempt failed. Inspect its effects and issue a new, explicitly approved recovery decision.';
      } else if (step.status == PluginRecoveryJobStepStatus.skipped) {
        disposition = PluginRecoveryJobStepDisposition.skippedNeedsDecision;
        guidance = 'This step was not run. Revalidate dependencies and authorize a new job before execution.';
      } else if (checkpoint == null) {
        disposition = PluginRecoveryJobStepDisposition.checkpointMissing;
        guidance = 'No plugin checkpoint exists; establish provenance and re-plan before execution.';
      } else if ((step.expectedCheckpointOperationId != null &&
                  checkpoint.operationId != step.expectedCheckpointOperationId) ||
                 (step.expectedCheckpointSequence != null &&
                  checkpoint.sequence != step.expectedCheckpointSequence)) {
        disposition = PluginRecoveryJobStepDisposition.checkpointChanged;
        guidance = 'The plugin checkpoint changed after this job was planned; re-plan against the current checkpoint.';
      } else {
        disposition = PluginRecoveryJobStepDisposition.pending;
        guidance = 'No step execution is recorded; host may authorize initial execution after fresh preflight.';
      }

      findings.add(PluginRecoveryJobStepFinding(
        pluginId: step.pluginId,
        ordinal: step.ordinal,
        disposition: disposition,
        guidance: guidance,
      ));
    }

    final dispositions = findings.map((f) => f.disposition).toSet();
    final PluginRecoveryJobDisposition overall;
    if (job.status == PluginRecoveryJobStatus.cancelled) {
      overall = PluginRecoveryJobDisposition.cancelled;
    } else if (job.status == PluginRecoveryJobStatus.interrupted) {
      overall = PluginRecoveryJobDisposition.interruptedNeedsInspection;
    } else if (job.status == PluginRecoveryJobStatus.failed ||
        job.status == PluginRecoveryJobStatus.manualReview) {
      overall = PluginRecoveryJobDisposition.failedNeedsDecision;
    } else if (dispositions.contains(PluginRecoveryJobStepDisposition.activeStateMismatch) ||
        dispositions.contains(PluginRecoveryJobStepDisposition.checkpointMissing) ||
        dispositions.contains(PluginRecoveryJobStepDisposition.checkpointChanged)) {
      overall = PluginRecoveryJobDisposition.inconsistent;
    } else if (dispositions.contains(PluginRecoveryJobStepDisposition.runningNeedsInspection)) {
      overall = PluginRecoveryJobDisposition.interruptedNeedsInspection;
    } else if (dispositions.contains(PluginRecoveryJobStepDisposition.failedNeedsDecision) ||
        dispositions.contains(PluginRecoveryJobStepDisposition.skippedNeedsDecision)) {
      overall = PluginRecoveryJobDisposition.failedNeedsDecision;
    } else if (findings.every((f) => f.disposition == PluginRecoveryJobStepDisposition.completedAndVerified)) {
      overall = PluginRecoveryJobDisposition.completed;
    } else if (findings.every((f) => f.disposition == PluginRecoveryJobStepDisposition.pending ||
        f.disposition == PluginRecoveryJobStepDisposition.completedAndVerified)) {
      overall = PluginRecoveryJobDisposition.readyToStart;
    } else {
      overall = PluginRecoveryJobDisposition.inconsistent;
    }

    return PluginRecoveryJobRecoveryReport(
      jobId: job.jobId,
      disposition: overall,
      steps: findings,
      activePluginIds: active,
    );
  }
}

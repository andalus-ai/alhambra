import 'plugin_lifecycle_recovery_job.dart';

/// Host-invoked durable cancellation request for a recovery job.
///
/// A planned job is cancelled immediately. A running job only receives a
/// durable request; the runner completes its in-flight plugin step and stops
/// before claiming another one. This controller never interrupts plugin code.
final class PluginLifecycleRecoveryJobCancellationController {
  final PluginLifecycleRecoveryJobStore store;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobCancellationController({
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleRecoveryJob> requestCancellation({
    required String jobId,
    required int expectedRevision,
  }) async {
    if (jobId.trim().isEmpty) throw ArgumentError.value(jobId, 'jobId');
    if (expectedRevision < 1) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final current = await store.read(jobId);
    if (current == null) throw StateError('Recovery job "$jobId" does not exist.');
    if (current.revision != expectedRevision) {
      throw StateError('Recovery job revision changed; refresh before requesting cancellation.');
    }
    if (current.status == PluginRecoveryJobStatus.cancellationRequested) {
      return current;
    }
    if (current.status != PluginRecoveryJobStatus.planned &&
        current.status != PluginRecoveryJobStatus.running) {
      throw StateError('Recovery job in state "${current.status.name}" cannot be cancelled.');
    }

    final requestedAt = _clock().toUtc();
    final nextStatus = current.status == PluginRecoveryJobStatus.planned
        ? PluginRecoveryJobStatus.cancelled
        : PluginRecoveryJobStatus.cancellationRequested;
    final steps = current.status == PluginRecoveryJobStatus.planned
        ? current.steps.map((step) => step.copyWith(
            status: PluginRecoveryJobStepStatus.skipped,
          )).toList(growable: false)
        : current.steps;
    final replacement = current.next(
      status: nextStatus,
      at: requestedAt,
      steps: steps,
      cancellationRequestedAt: requestedAt,
    );
    if (!await store.compareAndSet(
      jobId: current.jobId,
      expectedRevision: current.revision,
      replacement: replacement,
    )) {
      throw StateError('Recovery job changed while cancellation was being requested.');
    }
    return replacement;
  }
}

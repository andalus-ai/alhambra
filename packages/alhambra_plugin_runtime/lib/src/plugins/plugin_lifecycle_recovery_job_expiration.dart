import 'plugin_lifecycle_recovery_job.dart';

/// Read-only result of evaluating whether a recovery job may expire now.
enum PluginRecoveryJobExpirationDisposition {
  notConfigured,
  notDue,
  eligible,
  alreadyExpired,
  notPlanned,
}

final class PluginRecoveryJobExpirationReport {
  final String jobId;
  final PluginRecoveryJobExpirationDisposition disposition;
  final DateTime? expiresAt;
  final DateTime evaluatedAt;

  const PluginRecoveryJobExpirationReport({
    required this.jobId,
    required this.disposition,
    required this.expiresAt,
    required this.evaluatedAt,
  });

  bool get mayExpire =>
      disposition == PluginRecoveryJobExpirationDisposition.eligible;
}

/// Host-invoked expiry and retention operations.
///
/// This controller has no timer, scheduler, background worker, or deletion
/// behavior. The host decides when to inspect and invoke expiry.
final class PluginLifecycleRecoveryJobExpirationController {
  final PluginLifecycleRecoveryJobStore store;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobExpirationController({
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginRecoveryJobExpirationReport> inspect({
    required String jobId,
    DateTime? at,
  }) async {
    if (jobId.trim().isEmpty) throw ArgumentError.value(jobId, 'jobId');
    final job = await store.read(jobId);
    if (job == null) throw StateError('Recovery job "$jobId" does not exist.');
    final instant = (at ?? _clock()).toUtc();
    final PluginRecoveryJobExpirationDisposition disposition;
    if (job.status == PluginRecoveryJobStatus.expired) {
      disposition = PluginRecoveryJobExpirationDisposition.alreadyExpired;
    } else if (job.status != PluginRecoveryJobStatus.planned) {
      disposition = PluginRecoveryJobExpirationDisposition.notPlanned;
    } else if (job.expiresAt == null) {
      disposition = PluginRecoveryJobExpirationDisposition.notConfigured;
    } else if (instant.isBefore(job.expiresAt!)) {
      disposition = PluginRecoveryJobExpirationDisposition.notDue;
    } else {
      disposition = PluginRecoveryJobExpirationDisposition.eligible;
    }
    return PluginRecoveryJobExpirationReport(
      jobId: job.jobId,
      disposition: disposition,
      expiresAt: job.expiresAt,
      evaluatedAt: instant,
    );
  }

  /// Expires only a planned job whose immutable expiresAt has been reached.
  ///
  /// Revision CAS arbitrates expiry against execution claim and cancellation.
  /// A running or ambiguous job is never expired by this operation.
  Future<PluginLifecycleRecoveryJob> expire({
    required String jobId,
    required int expectedRevision,
    DateTime? at,
  }) async {
    if (jobId.trim().isEmpty) throw ArgumentError.value(jobId, 'jobId');
    if (expectedRevision < 1) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final current = await store.read(jobId);
    if (current == null) throw StateError('Recovery job "$jobId" does not exist.');
    if (current.revision != expectedRevision) {
      throw StateError('Recovery job revision changed; refresh before expiring it.');
    }
    if (current.status != PluginRecoveryJobStatus.planned) {
      throw StateError('Only a planned recovery job may expire.');
    }
    final expiresAt = current.expiresAt;
    if (expiresAt == null) {
      throw StateError('Recovery job has no expiration policy.');
    }
    final instant = (at ?? _clock()).toUtc();
    if (instant.isBefore(expiresAt)) {
      throw StateError('Recovery job has not reached its expiration time.');
    }
    final replacement = current.next(
      status: PluginRecoveryJobStatus.expired,
      at: instant,
      steps: current.steps.map((step) => step.copyWith(
        status: PluginRecoveryJobStepStatus.skipped,
      )),
      expiredAt: instant,
    );
    if (!await store.compareAndSet(
      jobId: current.jobId,
      expectedRevision: current.revision,
      replacement: replacement,
    )) {
      throw StateError('Recovery job changed while expiration was being applied.');
    }
    return replacement;
  }
}

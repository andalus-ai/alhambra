import 'plugin_lifecycle_recovery_job.dart';

/// Immutable archive envelope. Archival preserves the complete job snapshot;
/// it does not remove or mutate the operational job record.
final class PluginLifecycleRecoveryJobArchiveRecord {
  final PluginLifecycleRecoveryJob job;
  final DateTime archivedAt;

  PluginLifecycleRecoveryJobArchiveRecord({
    required this.job,
    required DateTime archivedAt,
  }) : archivedAt = archivedAt.toUtc() {
    if (this.archivedAt.isBefore(job.createdAt)) {
      throw ArgumentError('archivedAt must not precede job creation.');
    }
  }
}

/// Host-provided archive boundary.
///
/// Implementations must make putIfAbsent idempotent by job ID and reject a
/// conflicting snapshot for an already archived job. This contract does not
/// prescribe a database, object store, or serialization format.
abstract interface class PluginLifecycleRecoveryJobArchive {
  Future<PluginLifecycleRecoveryJobArchiveRecord?> read(String jobId);

  Future<bool> putIfAbsent(PluginLifecycleRecoveryJobArchiveRecord record);
}

/// Explicit archive operation. It never deletes from the operational store.
final class PluginLifecycleRecoveryJobArchiver {
  final PluginLifecycleRecoveryJobStore jobStore;
  final PluginLifecycleRecoveryJobArchive archive;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobArchiver({
    required this.jobStore,
    required this.archive,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginLifecycleRecoveryJobArchiveRecord> archiveJob({
    required String jobId,
    required int expectedRevision,
  }) async {
    if (jobId.trim().isEmpty) throw ArgumentError.value(jobId, 'jobId');
    if (expectedRevision < 1) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final job = await jobStore.read(jobId);
    if (job == null) throw StateError('Recovery job "$jobId" does not exist.');
    if (job.revision != expectedRevision) {
      throw StateError('Recovery job revision changed; refresh before archiving.');
    }
    if (!_isArchivable(job.status)) {
      throw StateError('Recovery job in state "${job.status.name}" is not eligible for archival.');
    }

    final existing = await archive.read(jobId);
    if (existing != null) {
      if (!_sameJobSnapshot(existing.job, job)) {
        throw StateError('An archive with a different job snapshot already exists.');
      }
      return existing;
    }

    final record = PluginLifecycleRecoveryJobArchiveRecord(
      job: job,
      archivedAt: _clock(),
    );
    if (!await archive.putIfAbsent(record)) {
      final raced = await archive.read(jobId);
      if (raced != null && _sameJobSnapshot(raced.job, job)) {
        return raced;
      }
      throw StateError('A conflicting archive record was written concurrently.');
    }
    return record;
  }

  bool _isArchivable(PluginRecoveryJobStatus status) => switch (status) {
    PluginRecoveryJobStatus.completed ||
    PluginRecoveryJobStatus.failed ||
    PluginRecoveryJobStatus.partiallyCompleted ||
    PluginRecoveryJobStatus.cancelled ||
    PluginRecoveryJobStatus.expired => true,
    PluginRecoveryJobStatus.planned ||
    PluginRecoveryJobStatus.running ||
    PluginRecoveryJobStatus.cancellationRequested ||
    PluginRecoveryJobStatus.interrupted ||
    PluginRecoveryJobStatus.manualReview => false,
  };
}

bool _sameJobSnapshot(
  PluginLifecycleRecoveryJob left,
  PluginLifecycleRecoveryJob right,
) {
  if (left.schemaVersion != right.schemaVersion ||
      left.jobId != right.jobId ||
      left.idempotencyKey != right.idempotencyKey ||
      left.operationId != right.operationId ||
      left.action != right.action ||
      left.status != right.status ||
      left.revision != right.revision ||
      left.createdAt != right.createdAt ||
      left.updatedAt != right.updatedAt ||
      left.initiatedBy != right.initiatedBy ||
      left.correlationId != right.correlationId ||
      left.failureCode != right.failureCode ||
      left.failureSummary != right.failureSummary ||
      left.cancellationRequestedAt != right.cancellationRequestedAt ||
      left.expiresAt != right.expiresAt ||
      left.expiredAt != right.expiredAt ||
      left.orderedPluginIds.length != right.orderedPluginIds.length ||
      left.steps.length != right.steps.length) {
    return false;
  }
  for (var i = 0; i < left.orderedPluginIds.length; i++) {
    if (left.orderedPluginIds[i] != right.orderedPluginIds[i]) return false;
  }
  for (var i = 0; i < left.steps.length; i++) {
    final a = left.steps[i];
    final b = right.steps[i];
    if (a.pluginId != b.pluginId ||
        a.ordinal != b.ordinal ||
        a.status != b.status ||
        a.expectedCheckpointOperationId != b.expectedCheckpointOperationId ||
        a.expectedCheckpointSequence != b.expectedCheckpointSequence ||
        a.executionOperationId != b.executionOperationId ||
        a.startedAt != b.startedAt ||
        a.completedAt != b.completedAt ||
        a.failureCode != b.failureCode ||
        a.failureSummary != b.failureSummary) {
      return false;
    }
  }
  return true;
}

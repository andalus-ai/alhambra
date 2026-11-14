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
      if (existing.job.revision != job.revision ||
          existing.job.updatedAt != job.updatedAt ||
          existing.job.status != job.status) {
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
      if (raced != null &&
          raced.job.revision == job.revision &&
          raced.job.updatedAt == job.updatedAt &&
          raced.job.status == job.status) {
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
    PluginRecoveryJobStatus.interrupted ||
    PluginRecoveryJobStatus.manualReview ||
    PluginRecoveryJobStatus.cancelled ||
    PluginRecoveryJobStatus.expired => true,
    PluginRecoveryJobStatus.planned ||
    PluginRecoveryJobStatus.running ||
    PluginRecoveryJobStatus.cancellationRequested => false,
  };
}

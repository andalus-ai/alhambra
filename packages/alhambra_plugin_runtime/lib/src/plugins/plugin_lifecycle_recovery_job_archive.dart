import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity.dart';

/// Immutable archive envelope for a terminal recovery job.
final class PluginLifecycleRecoveryJobArchiveRecord {
  final PluginLifecycleRecoveryJob job;
  final DateTime archivedAt;
  final PluginLifecycleRecoveryJobArchiveIntegrity integrity;

  PluginLifecycleRecoveryJobArchiveRecord({
    required this.job,
    required DateTime archivedAt,
    required this.integrity,
  }) : archivedAt = archivedAt.toUtc() {
    if (this.archivedAt.isBefore(job.createdAt)) {
      throw ArgumentError('archivedAt must not precede job creation.');
    }
  }
}

/// Host-provided archive boundary. putIfAbsent must be atomic by job ID and
/// reject conflicting snapshots.
abstract interface class PluginLifecycleRecoveryJobArchive {
  Future<PluginLifecycleRecoveryJobArchiveRecord?> read(String jobId);
  Future<bool> putIfAbsent(PluginLifecycleRecoveryJobArchiveRecord record);
}

/// Optional stronger archive adapter contract for explicit purge operations.
/// Implementations must compare the stored digest atomically before deletion.
abstract interface class PluginLifecycleRecoveryJobArchivePurgeStore
    implements PluginLifecycleRecoveryJobArchive {
  Future<bool> deleteIfDigestMatches({
    required String jobId,
    required String expectedDigest,
  });
}

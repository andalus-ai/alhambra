import 'dart:convert';

import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_job_archive.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity_metadata.dart';

/// Stable JSON representation used as the input to an archive digest.
///
/// The schema is intentionally explicit: adding a persisted job field requires
/// updating this codec and its golden tests before archive format evolution.
final class PluginLifecycleRecoveryJobSnapshotCodec {
  static const int formatVersion = 1;

  const PluginLifecycleRecoveryJobSnapshotCodec();

  String encode(PluginLifecycleRecoveryJob job) => jsonEncode({
    'formatVersion': formatVersion,
    'schemaVersion': job.schemaVersion,
    'jobId': job.jobId,
    'idempotencyKey': job.idempotencyKey,
    'operationId': job.operationId,
    'action': job.action.name,
    'orderedPluginIds': job.orderedPluginIds,
    'steps': job.steps.map((step) => {
      'pluginId': step.pluginId,
      'ordinal': step.ordinal,
      'status': step.status.name,
      'expectedCheckpointOperationId': step.expectedCheckpointOperationId,
      'expectedCheckpointSequence': step.expectedCheckpointSequence,
      'executionOperationId': step.executionOperationId,
      'startedAt': _date(step.startedAt),
      'completedAt': _date(step.completedAt),
      'failureCode': step.failureCode,
      'failureSummary': step.failureSummary,
    }).toList(growable: false),
    'status': job.status.name,
    'revision': job.revision,
    'createdAt': job.createdAt.toUtc().toIso8601String(),
    'updatedAt': job.updatedAt.toUtc().toIso8601String(),
    'initiatedBy': job.initiatedBy,
    'correlationId': job.correlationId,
    'failureCode': job.failureCode,
    'failureSummary': job.failureSummary,
    'cancellationRequestedAt': _date(job.cancellationRequestedAt),
    'expiresAt': _date(job.expiresAt),
    'expiredAt': _date(job.expiredAt),
  });

  static String? _date(DateTime? value) => value?.toUtc().toIso8601String();
}

/// Cryptographic digest implementation supplied by the host.
///
/// Production hosts should use a vetted cryptographic hash (for example
/// SHA-256) and pin the algorithm identifier. No weak/default hash is supplied.
abstract interface class PluginLifecycleRecoveryJobDigestProvider {
  Future<String> digest({
    required String algorithm,
    required String canonicalPayload,
  });
}


enum PluginRecoveryArchiveVerificationDisposition {
  valid,
  missing,
  unsupportedFormat,
  unsupportedJobSchema,
  invalidDigest,
}

final class PluginRecoveryArchiveVerificationReport {
  final String jobId;
  final PluginRecoveryArchiveVerificationDisposition disposition;
  final String? expectedDigest;
  final String? actualDigest;

  const PluginRecoveryArchiveVerificationReport({
    required this.jobId,
    required this.disposition,
    required this.expectedDigest,
    required this.actualDigest,
  });

  bool get isValid =>
      disposition == PluginRecoveryArchiveVerificationDisposition.valid;
}

/// Verifies archived job snapshots without mutating either store.
final class PluginLifecycleRecoveryJobArchiveVerifier {
  final PluginLifecycleRecoveryJobArchive archive;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final PluginLifecycleRecoveryJobSnapshotCodec codec;

  const PluginLifecycleRecoveryJobArchiveVerifier({
    required this.archive,
    required this.digestProvider,
    this.codec = const PluginLifecycleRecoveryJobSnapshotCodec(),
  });

  Future<PluginRecoveryArchiveVerificationReport> verify(String jobId) async {
    final record = await archive.read(jobId);
    if (record == null) {
      return PluginRecoveryArchiveVerificationReport(
        jobId: jobId,
        disposition: PluginRecoveryArchiveVerificationDisposition.missing,
        expectedDigest: null,
        actualDigest: null,
      );
    }
    if (record.integrity.formatVersion !=
        PluginLifecycleRecoveryJobSnapshotCodec.formatVersion) {
      return PluginRecoveryArchiveVerificationReport(
        jobId: jobId,
        disposition: PluginRecoveryArchiveVerificationDisposition.unsupportedFormat,
        expectedDigest: record.integrity.digest,
        actualDigest: null,
      );
    }
    if (record.job.schemaVersion != PluginLifecycleRecoveryJob.currentSchemaVersion) {
      return PluginRecoveryArchiveVerificationReport(
        jobId: jobId,
        disposition: PluginRecoveryArchiveVerificationDisposition.unsupportedJobSchema,
        expectedDigest: record.integrity.digest,
        actualDigest: null,
      );
    }
    final actual = await digestProvider.digest(
      algorithm: record.integrity.algorithm,
      canonicalPayload: codec.encode(record.job),
    );
    return PluginRecoveryArchiveVerificationReport(
      jobId: jobId,
      disposition: actual == record.integrity.digest
          ? PluginRecoveryArchiveVerificationDisposition.valid
          : PluginRecoveryArchiveVerificationDisposition.invalidDigest,
      expectedDigest: record.integrity.digest,
      actualDigest: actual,
    );
  }
}

/// Imports only a verified archived snapshot. Import never executes plugins,
/// changes checkpoint state, or resumes a recovery job.
final class PluginLifecycleRecoveryJobArchiveRestorer {
  final PluginLifecycleRecoveryJobArchive archive;
  final PluginLifecycleRecoveryJobStore jobStore;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final PluginLifecycleRecoveryJobSnapshotCodec codec;

  const PluginLifecycleRecoveryJobArchiveRestorer({
    required this.archive,
    required this.jobStore,
    required this.digestProvider,
    this.codec = const PluginLifecycleRecoveryJobSnapshotCodec(),
  });

  Future<PluginLifecycleRecoveryJobRestoreResult> restore({
    required String jobId,
  }) async {
    final verification = await PluginLifecycleRecoveryJobArchiveVerifier(
      archive: archive,
      digestProvider: digestProvider,
      codec: codec,
    ).verify(jobId);
    if (!verification.isValid) {
      throw StateError('Archive verification failed: ${verification.disposition.name}.');
    }
    final record = await archive.read(jobId);
    if (record == null) throw StateError('Archive "$jobId" disappeared during restore.');
    if (record.integrity.digest != verification.expectedDigest ||
        record.integrity.formatVersion !=
            PluginLifecycleRecoveryJobSnapshotCodec.formatVersion) {
      throw StateError('Archive changed between verification and restore.');
    }
    final existing = await jobStore.read(jobId);
    if (existing != null) {
      if (const _ArchiveSnapshotEquality().matches(existing, record.job)) {
        return PluginLifecycleRecoveryJobRestoreResult(
          job: existing,
          disposition: PluginLifecycleRecoveryJobRestoreDisposition.alreadyPresent,
        );
      }
      throw StateError('An operational job with this ID has a different snapshot.');
    }
    if (!await jobStore.insertIfAbsent(record.job)) {
      final raced = await jobStore.read(jobId);
      if (raced != null && const _ArchiveSnapshotEquality().matches(raced, record.job)) {
        return PluginLifecycleRecoveryJobRestoreResult(
          job: raced,
          disposition: PluginLifecycleRecoveryJobRestoreDisposition.alreadyPresent,
        );
      }
      throw StateError('Restore conflicted with an existing job or idempotency key.');
    }
    return PluginLifecycleRecoveryJobRestoreResult(
      job: record.job,
      disposition: PluginLifecycleRecoveryJobRestoreDisposition.restored,
    );
  }
}

enum PluginLifecycleRecoveryJobRestoreDisposition { restored, alreadyPresent }

final class PluginLifecycleRecoveryJobRestoreResult {
  final PluginLifecycleRecoveryJob job;
  final PluginLifecycleRecoveryJobRestoreDisposition disposition;

  const PluginLifecycleRecoveryJobRestoreResult({
    required this.job,
    required this.disposition,
  });
}

final class _ArchiveSnapshotEquality {
  const _ArchiveSnapshotEquality();

  bool matches(PluginLifecycleRecoveryJob left, PluginLifecycleRecoveryJob right) {
    const codec = PluginLifecycleRecoveryJobSnapshotCodec();
    return codec.encode(left) == codec.encode(right);
  }
}

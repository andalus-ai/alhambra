import 'plugin_lifecycle_recovery_job.dart';
import 'plugin_lifecycle_recovery_job_archive.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity_metadata.dart';

/// Explicit archive operation. It never deletes from the operational store.
final class PluginLifecycleRecoveryJobArchiver {
  final PluginLifecycleRecoveryJobStore jobStore;
  final PluginLifecycleRecoveryJobArchive archive;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final PluginLifecycleRecoveryJobSnapshotCodec codec;
  final String digestAlgorithm;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobArchiver({
    required this.jobStore,
    required this.archive,
    required this.digestProvider,
    this.codec = const PluginLifecycleRecoveryJobSnapshotCodec(),
    required this.digestAlgorithm,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (digestAlgorithm.trim().isEmpty) {
      throw ArgumentError.value(digestAlgorithm, 'digestAlgorithm');
    }
  }

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

    final payload = codec.encode(job);
    final digest = await digestProvider.digest(
      algorithm: digestAlgorithm,
      canonicalPayload: payload,
    );
    if (digest.trim().isEmpty) {
      throw StateError('Digest provider returned an empty digest.');
    }
    final existing = await archive.read(jobId);
    if (existing != null) {
      if (!_sameJobSnapshot(existing.job, job) ||
          existing.integrity.formatVersion !=
              PluginLifecycleRecoveryJobSnapshotCodec.formatVersion ||
          existing.integrity.algorithm != digestAlgorithm ||
          existing.integrity.digest != digest) {
        throw StateError('An archive with a different snapshot or digest already exists.');
      }
      return existing;
    }

    final record = PluginLifecycleRecoveryJobArchiveRecord(
      job: job,
      archivedAt: _clock(),
      integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
        formatVersion: PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
        algorithm: digestAlgorithm,
        digest: digest,
      ),
    );
    if (!await archive.putIfAbsent(record)) {
      final raced = await archive.read(jobId);
      if (raced != null &&
          _sameJobSnapshot(raced.job, job) &&
          raced.integrity.formatVersion ==
              PluginLifecycleRecoveryJobSnapshotCodec.formatVersion &&
          raced.integrity.algorithm == digestAlgorithm &&
          raced.integrity.digest == digest) {
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
) => const PluginLifecycleRecoveryJobSnapshotCodec().encode(left) ==
    const PluginLifecycleRecoveryJobSnapshotCodec().encode(right);

/// Host-owned retention inputs. Alhambra does not persist or infer legal policy.
final class PluginLifecycleRecoveryJobRetentionPolicy {
  final DateTime retainUntil;
  final bool legalHold;
  final bool auditPreservationRequired;

  PluginLifecycleRecoveryJobRetentionPolicy({
    required DateTime retainUntil,
    this.legalHold = false,
    this.auditPreservationRequired = false,
  }) : retainUntil = retainUntil.toUtc();
}

enum PluginRecoveryArchiveRetentionDisposition {
  missing,
  notTerminal,
  retentionPeriodActive,
  legalHold,
  auditPreservationRequired,
  eligibleForExplicitPurge,
}

final class PluginRecoveryArchiveRetentionReport {
  final String jobId;
  final PluginRecoveryArchiveRetentionDisposition disposition;
  final DateTime evaluatedAt;
  final DateTime retainUntil;
  final bool legalHold;
  final bool auditPreservationRequired;
  final String? archiveDigest;

  const PluginRecoveryArchiveRetentionReport({
    required this.jobId,
    required this.disposition,
    required this.evaluatedAt,
    required this.retainUntil,
    required this.legalHold,
    required this.auditPreservationRequired,
    required this.archiveDigest,
  });

  bool get eligibleForPurge =>
      disposition == PluginRecoveryArchiveRetentionDisposition.eligibleForExplicitPurge;
}

/// Read-only retention evaluation. It never deletes or modifies archive data.
final class PluginLifecycleRecoveryJobRetentionInspector {
  final PluginLifecycleRecoveryJobArchive archive;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobRetentionInspector({
    required this.archive,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginRecoveryArchiveRetentionReport> inspect({
    required String jobId,
    required PluginLifecycleRecoveryJobRetentionPolicy policy,
    DateTime? at,
  }) async {
    final instant = (at ?? _clock()).toUtc();
    final record = await archive.read(jobId);
    final PluginRecoveryJobArchiveRetentionDisposition disposition;
    if (record == null) {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.missing;
    } else if (!_isTerminal(record.job.status)) {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.notTerminal;
    } else if (policy.legalHold) {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.legalHold;
    } else if (policy.auditPreservationRequired) {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.auditPreservationRequired;
    } else if (instant.isBefore(policy.retainUntil)) {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.retentionPeriodActive;
    } else {
      disposition = PluginRecoveryJobArchiveRetentionDisposition.eligibleForExplicitPurge;
    }
    return PluginRecoveryArchiveRetentionReport(
      jobId: jobId,
      disposition: disposition,
      evaluatedAt: instant,
      retainUntil: policy.retainUntil,
      legalHold: policy.legalHold,
      auditPreservationRequired: policy.auditPreservationRequired,
      archiveDigest: record?.integrity.digest,
    );
  }

  bool _isTerminal(PluginRecoveryJobStatus status) => switch (status) {
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

/// Explicit approval evidence supplied by the host's authorization system.
final class PluginRecoveryArchivePurgeAuthorization {
  final String authorizedBy;
  final String approvalReference;
  final DateTime approvedAt;

  PluginRecoveryArchivePurgeAuthorization({
    required this.authorizedBy,
    required this.approvalReference,
    required DateTime approvedAt,
  }) : approvedAt = approvedAt.toUtc() {
    if (authorizedBy.trim().isEmpty || approvalReference.trim().isEmpty) {
      throw ArgumentError('Purge authorization requires an actor and approval reference.');
    }
  }
}

final class PluginRecoveryArchivePurgeAuditEvent {
  final String jobId;
  final String archiveDigest;
  final String authorizedBy;
  final String approvalReference;
  final DateTime approvedAt;
  final DateTime purgeRequestedAt;

  const PluginRecoveryArchivePurgeAuditEvent({
    required this.jobId,
    required this.archiveDigest,
    required this.authorizedBy,
    required this.approvalReference,
    required this.approvedAt,
    required this.purgeRequestedAt,
  });
}

abstract interface class PluginRecoveryArchivePurgeAuditSink {
  /// Must durably record the event before returning successfully.
  Future<void> record(PluginRecoveryArchivePurgeAuditEvent event);
}

/// Host authorization adapter. A non-empty approval reference alone is not
/// authorization; the host must validate its identity, scope, and permissions.
abstract interface class PluginRecoveryArchivePurgeAuthorizer {
  Future<bool> authorize({
    required String jobId,
    required String archiveDigest,
    required PluginRecoveryArchivePurgeAuthorization authorization,
  });
}

enum PluginRecoveryArchivePurgeDisposition { purged }

/// Purges only an archived copy after explicit host approval and retention
/// checks. The operational job store is never touched.
final class PluginLifecycleRecoveryJobArchivePurger {
  final PluginLifecycleRecoveryJobArchivePurgeStore archive;
  final PluginLifecycleRecoveryJobRetentionInspector inspector;
  final PluginRecoveryArchivePurgeAuditSink auditSink;
  final PluginRecoveryArchivePurgeAuthorizer authorizer;
  final PluginLifecycleRecoveryJobArchiveVerifier verifier;
  final DateTime Function() _clock;

  PluginLifecycleRecoveryJobArchivePurger({
    required this.archive,
    required this.inspector,
    required this.auditSink,
    required this.authorizer,
    required this.verifier,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginRecoveryArchivePurgeDisposition> purge({
    required String jobId,
    required PluginLifecycleRecoveryJobRetentionPolicy policy,
    required PluginRecoveryArchivePurgeAuthorization authorization,
    required String expectedDigest,
    DateTime? at,
  }) async {
    if (jobId.trim().isEmpty || expectedDigest.trim().isEmpty) {
      throw ArgumentError('jobId and expectedDigest are required.');
    }
    final report = await inspector.inspect(jobId: jobId, policy: policy, at: at);
    if (!report.eligibleForPurge) {
      throw StateError('Archive is not eligible for purge: ${report.disposition.name}.');
    }
    if (report.archiveDigest != expectedDigest) {
      throw StateError('Archive digest changed; refresh and re-authorize purge.');
    }
    if (!await authorizer.authorize(
      jobId: jobId,
      archiveDigest: expectedDigest,
      authorization: authorization,
    )) {
      throw StateError('Host authorization denied archive purge.');
    }
    final requestedAt = (at ?? _clock()).toUtc();
    if (authorization.approvedAt.isAfter(requestedAt)) {
      throw StateError('Purge approval timestamp cannot be in the future.');
    }
    final verification = await verifier.verify(jobId);
    if (!verification.isValid || verification.expectedDigest != expectedDigest) {
      throw StateError('Archive integrity verification failed; purge is blocked.');
    }
    await auditSink.record(PluginRecoveryArchivePurgeAuditEvent(
      jobId: jobId,
      archiveDigest: expectedDigest,
      authorizedBy: authorization.authorizedBy,
      approvalReference: authorization.approvalReference,
      approvedAt: authorization.approvedAt,
      purgeRequestedAt: requestedAt,
    ));
    if (!await archive.deleteIfDigestMatches(
      jobId: jobId,
      expectedDigest: expectedDigest,
    )) {
      throw StateError('Archive changed or disappeared before purge completed.');
    }
    return PluginRecoveryArchivePurgeDisposition.purged;
  }
}

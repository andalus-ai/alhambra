import 'plugin_revocation_access_audit_archive.dart';
import 'plugin_revocation_admin_operations.dart';

/// Ordered archive segments for one scope. Checkpoint digests must be supplied
/// only after the host has verified the corresponding signed checkpoints.
final class PluginRevocationAccessAuditArchiveSet {
  final String manifestId;
  final String scopeId;
  final List<PluginRevocationAccessAuditArchivePackage> packages;

  PluginRevocationAccessAuditArchiveSet({
    required this.manifestId,
    required this.scopeId,
    required Iterable<PluginRevocationAccessAuditArchivePackage> packages,
  }) : packages = List.unmodifiable(packages) {
    if (manifestId.trim().isEmpty || scopeId.trim().isEmpty ||
        this.packages.isEmpty) {
      throw ArgumentError('An archive set requires an ID, scope, and packages.');
    }
  }
}

final class PluginRevocationAccessAuditArchiveSetVerification {
  final bool valid;
  final String scopeId;
  final int verifiedPackages;
  final int verifiedEntries;
  final int? failedPackageIndex;
  final String reason;
  final int? fromSequence;
  final int? toSequence;
  final String? headHash;

  const PluginRevocationAccessAuditArchiveSetVerification({
    required this.valid, required this.scopeId,
    required this.verifiedPackages, required this.verifiedEntries,
    required this.reason, this.failedPackageIndex, this.fromSequence,
    this.toSequence, this.headHash,
  });
}

abstract final class PluginRevocationAccessAuditArchiveSetCodec {
  /// Verifies package contents and inter-package continuity in supplied order.
  /// Does not sort, repair, or silently skip missing segments.
  static PluginRevocationAccessAuditArchiveSetVerification verify(
    PluginRevocationAccessAuditArchiveSet archiveSet, {
    required Set<String> verifiedCheckpointDigests,
  }) {
    final ids = <String>{};
    var entriesVerified = 0;
    PluginRevocationAccessAuditArchivePackage? previous;
    for (var i = 0; i < archiveSet.packages.length; i++) {
      final package = archiveSet.packages[i];
      if (package.scopeId != archiveSet.scopeId) {
        return _failure(archiveSet, i, entriesVerified, 'scope_mismatch');
      }
      if (!ids.add(package.packageId)) {
        return _failure(archiveSet, i, entriesVerified, 'duplicate_package');
      }
      if (!verifiedCheckpointDigests.contains(package.checkpointDigest)) {
        return _failure(archiveSet, i, entriesVerified, 'checkpoint_not_verified');
      }
      final verification = PluginRevocationAccessAuditArchiveCodec.verify(package);
      if (!verification.valid) {
        return _failure(archiveSet, i, entriesVerified, 'package_invalid');
      }
      if (previous != null) {
        if (package.fromSequence <= previous.toSequence) {
          return _failure(archiveSet, i, entriesVerified, 'overlap_or_reorder');
        }
        if (package.fromSequence != previous.toSequence + 1) {
          return _failure(archiveSet, i, entriesVerified, 'sequence_gap');
        }
        if (package.previousHash != previous.headHash) {
          return _failure(archiveSet, i, entriesVerified, 'hash_link_mismatch');
        }
      }
      previous = package;
      entriesVerified += verification.verifiedEntries;
    }
    final first = archiveSet.packages.first;
    final last = archiveSet.packages.last;
    return PluginRevocationAccessAuditArchiveSetVerification(
      valid: true, scopeId: archiveSet.scopeId,
      verifiedPackages: archiveSet.packages.length,
      verifiedEntries: entriesVerified, reason: 'verified',
      fromSequence: first.fromSequence, toSequence: last.toSequence,
      headHash: last.headHash,
    );
  }

  static PluginRevocationAccessAuditArchiveSetVerification _failure(
    PluginRevocationAccessAuditArchiveSet set, int index,
    int entriesVerified, String reason,
  ) => PluginRevocationAccessAuditArchiveSetVerification(
    valid: false, scopeId: set.scopeId, verifiedPackages: index,
    verifiedEntries: entriesVerified, failedPackageIndex: index, reason: reason,
  );
}

/// Host-owned retention policy. Sequences below minimumRetainedSequence may
/// be considered; the boundary sequence itself is always retained.
final class PluginRevocationAccessAuditRetentionPolicy {
  final String policyVersion;
  final Duration minimumAge;
  final int minimumRetainedSequence;
  final bool legalHold;

  const PluginRevocationAccessAuditRetentionPolicy({
    required this.policyVersion, required this.minimumAge,
    required this.minimumRetainedSequence, this.legalHold = false,
  }) {
    if (policyVersion.trim().isEmpty || minimumAge.isNegative ||
        minimumRetainedSequence < 1) {
      throw ArgumentError('Invalid audit retention policy.');
    }
  }
}

final class PluginRevocationAccessAuditRetentionRequest {
  final String scopeId;
  final int fromSequence;
  final int throughSequence;
  final DateTime oldestRecordAt;
  final PluginRevocationAccessAuditArchiveSet archiveSet;
  final Set<String> verifiedCheckpointDigests;
  final bool immutableStorageConfirmed;

  PluginRevocationAccessAuditRetentionRequest({
    required this.scopeId, required this.fromSequence,
    required this.throughSequence, required this.oldestRecordAt,
    required this.archiveSet, required Set<String> verifiedCheckpointDigests,
    required this.immutableStorageConfirmed,
  }) : verifiedCheckpointDigests = Set.unmodifiable(verifiedCheckpointDigests) {
    if (scopeId.trim().isEmpty || fromSequence < 1 ||
        throughSequence < fromSequence) {
      throw ArgumentError('Invalid audit retention request.');
    }
  }
}

abstract interface class PluginRevocationAccessAuditRetentionAuthorizer {
  Future<bool> canPlanRetention({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId, required int fromSequence,
    required int throughSequence, required String policyVersion,
  });
}

final class PluginRevocationAccessAuditRetentionPlan {
  final String scopeId;
  final int fromSequence;
  final int throughSequence;
  final String policyVersion;
  final String archiveManifestId;
  final int archiveVerifiedPackages;
  final int archiveVerifiedEntries;
  final DateTime plannedAt;
  /// Always false: this service never authorizes or executes deletion.
  final bool deletionAuthorized;
  final String disposition;

  const PluginRevocationAccessAuditRetentionPlan({
    required this.scopeId, required this.fromSequence,
    required this.throughSequence, required this.policyVersion,
    required this.archiveManifestId, required this.archiveVerifiedPackages,
    required this.archiveVerifiedEntries, required this.plannedAt,
    required this.deletionAuthorized, required this.disposition,
  });
}

final class PluginRevocationAccessAuditRetentionDeniedException
    implements Exception {
  final String reason;
  const PluginRevocationAccessAuditRetentionDeniedException(this.reason);
  @override
  String toString() => 'Audit retention plan denied: $reason';
}

/// Produces an auditable plan only. No source rows are deleted and no
/// persistence adapter is invoked; a host must implement a separate approved
/// maintenance workflow after backup and recovery validation.
final class PluginRevocationAccessAuditRetentionService {
  final PluginRevocationAccessAuditRetentionAuthorizer authorizer;
  final DateTime Function() clock;

  PluginRevocationAccessAuditRetentionService({
    required this.authorizer, DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAccessAuditRetentionPlan> plan({
    required PluginRevocationOperationsPrincipal principal,
    required PluginRevocationAccessAuditRetentionPolicy policy,
    required PluginRevocationAccessAuditRetentionRequest request,
  }) async {
    final now = clock().toUtc();
    if (policy.legalHold) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('legal_hold');
    }
    if (request.archiveSet.scopeId != request.scopeId) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('archive_scope_mismatch');
    }
    if (!request.immutableStorageConfirmed) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('immutable_archive_not_confirmed');
    }
    final archiveVerification = PluginRevocationAccessAuditArchiveSetCodec.verify(
      request.archiveSet,
      verifiedCheckpointDigests: request.verifiedCheckpointDigests,
    );
    if (!archiveVerification.valid) {
      throw PluginRevocationAccessAuditRetentionDeniedException(
        'archive_${archiveVerification.reason}',
      );
    }
    if (archiveVerification.fromSequence! > request.fromSequence ||
        archiveVerification.toSequence! < request.throughSequence) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('archive_does_not_cover_requested_range');
    }
    if (request.throughSequence >= policy.minimumRetainedSequence) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('minimum_retained_sequence');
    }
    final oldest = request.oldestRecordAt.toUtc();
    if (oldest.isAfter(now) || now.difference(oldest) < policy.minimumAge) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('minimum_age_not_met');
    }
    if (!await authorizer.canPlanRetention(
      principal: principal, scopeId: request.scopeId,
      fromSequence: request.fromSequence, throughSequence: request.throughSequence,
      policyVersion: policy.policyVersion,
    )) {
      throw const PluginRevocationAccessAuditRetentionDeniedException('authorization_denied');
    }
    return PluginRevocationAccessAuditRetentionPlan(
      scopeId: request.scopeId, fromSequence: request.fromSequence,
      throughSequence: request.throughSequence, policyVersion: policy.policyVersion,
      archiveManifestId: request.archiveSet.manifestId,
      archiveVerifiedPackages: archiveVerification.verifiedPackages,
      archiveVerifiedEntries: archiveVerification.verifiedEntries,
      plannedAt: now, deletionAuthorized: false,
      disposition: 'plan_only_requires_separate_approval',
    );
  }
}

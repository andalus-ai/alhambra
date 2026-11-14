import 'packaging_contracts.dart';

/// Package archive extension required by the transactional installer.
///
/// Archive adapters must expose entries without extracting them to disk.
abstract interface class PluginPackageArchive implements PluginPackage {
  Stream<PluginArchiveEntry> listEntries();
}

/// Entry kind is explicit so installers can reject links and special files.
enum PluginArchiveEntryKind { file, directory, symbolicLink, other }

final class PluginArchiveEntry {
  final String path;
  final PluginArchiveEntryKind kind;
  final int? declaredSizeBytes;

  const PluginArchiveEntry({
    required this.path,
    required this.kind,
    this.declaredSizeBytes,
  });
}

/// A host-owned staging handle. It must not be treated as a final install path.
final class PluginInstallStaging {
  final String operationId;
  final String pluginId;
  final String opaqueHandle;

  const PluginInstallStaging({
    required this.operationId,
    required this.pluginId,
    required this.opaqueHandle,
  });
}

/// Filesystem adapter with an explicit reversible promotion boundary.
///
/// [destinationPathFor] must be deterministic and side-effect free. The
/// installer journals the destination before calling [promote]. Promotion
/// must preserve enough state for [rollbackPromotion] until finalization.
/// Rollback must be safe after an ambiguous promotion error: it restores any
/// prior destination or removes the newly promoted tree, and is a no-op when
/// promotion never took effect. Implementations should use same-filesystem
/// atomic rename where supported and must never overwrite an unrelated tree.
abstract interface class PluginInstallFileSystem {
  Future<PluginInstallStaging> createStaging({
    required String operationId,
    required String pluginId,
    required String version,
  });

  Future<void> createDirectory(
    PluginInstallStaging staging,
    String relativePath,
  );

  Future<void> writeFile({
    required PluginInstallStaging staging,
    required String relativePath,
    required Stream<List<int>> bytes,
    required int maxBytes,
  });

  Future<String> destinationPathFor({
    required String pluginId,
    required String version,
  });

  Future<void> promote(
    PluginInstallStaging staging, {
    required String destinationPath,
  });

  Future<void> rollbackPromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  });

  Future<void> finalizePromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  });

  Future<void> discardStaging(PluginInstallStaging staging);

  /// Read-only, operation-scoped inspection. The adapter must prove staging
  /// ownership from the opaque handle or operation marker, not from path
  /// similarity. Must not repair, delete, promote or mutate files.
  Future<PluginInstallRecoverySnapshot> inspectOperation({
    required String operationId,
    required String pluginId,
    required String? stagingHandle,
    required String? destinationPath,
  });
}

/// Host compatibility/dependency preflight. Must not execute plugin code.
abstract interface class PluginInstallPreflight {
  Future<void> validate(PluginPackage package);
}

enum PluginInstallJournalStatus {
  verificationStarted,
  verified,
  stagingCreated,
  extracting,
  promoting,
  promoted,
  installedRecordSaved,
  committed,
  rollingBack,
  rolledBack,
  failed,
  needsReconciliation,
  recoveryStarted,
}

/// [unresolved] returns exactly the latest non-terminal entry per operation ID.
/// Writes must be durable before the corresponding external side effect.
final class PluginInstallJournalEntry {
  final String operationId;
  final String pluginId;
  final String version;
  final PluginInstallJournalStatus status;
  final DateTime updatedAt;
  final String? stagingHandle;
  final String? promotedPath;
  final String? failureCode;
  final String? contentHash;
  final String? approvedBy;
  final String? approvalId;

  const PluginInstallJournalEntry({
    required this.operationId,
    required this.pluginId,
    required this.version,
    required this.status,
    required this.updatedAt,
    this.stagingHandle,
    this.promotedPath,
    this.failureCode,
    this.contentHash,
    this.approvedBy,
    this.approvalId,
  });
}

abstract interface class PluginInstallJournal {
  Future<void> write(PluginInstallJournalEntry entry);
  Future<List<PluginInstallJournalEntry>> unresolved();
}

/// Resource limits applied before and during extraction.
final class PluginInstallLimits {
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;

  const PluginInstallLimits({
    this.maxEntries = 10000,
    this.maxEntryBytes = 64 * 1024 * 1024,
    this.maxTotalBytes = 512 * 1024 * 1024,
  })  : assert(maxEntries > 0),
        assert(maxEntryBytes > 0),
        assert(maxTotalBytes > 0);
}

/// Installed-record adapter with create-only and compare-and-remove semantics.
///
/// These operations must be atomic in a production adapter. They prevent a
/// failed installation from overwriting or deleting a concurrent install.
abstract interface class TransactionalInstalledPluginStore
    implements InstalledPluginStore {
  Future<bool> createIfAbsent(InstalledPluginRecord plugin);
  Future<bool> removeIfMatches(InstalledPluginRecord plugin);
}


/// Read-only facts returned by a host filesystem adapter during reconciliation.
///
/// Both staging and destination facts must be based on adapter-owned
/// operation provenance (for example a durable operation marker), not merely
/// on matching path names.
final class PluginInstallRecoverySnapshot {
  final bool stagingExists;
  final bool destinationExists;
  final bool destinationOwnedByOperation;
  final bool rollbackAvailable;

  const PluginInstallRecoverySnapshot({
    required this.stagingExists,
    required this.destinationExists,
    required this.destinationOwnedByOperation,
    required this.rollbackAvailable,
  });

  @override
  bool operator ==(Object other) =>
      other is PluginInstallRecoverySnapshot &&
      other.stagingExists == stagingExists &&
      other.destinationExists == destinationExists &&
      other.destinationOwnedByOperation == destinationOwnedByOperation &&
      other.rollbackAvailable == rollbackAvailable;

  @override
  int get hashCode => Object.hash(
        stagingExists,
        destinationExists,
        destinationOwnedByOperation,
        rollbackAvailable,
      );
}

/// Journal adapter that supports stale-safe recovery claims.
///
/// The compare-and-set must be atomic and durable. It must update only when
/// the latest entry for [operationId] still has both [expectedStatus] and
/// [expectedUpdatedAt]. The host must fence the original installer worker or
/// prove its operation lease has expired before allowing a recovery claim.
abstract interface class PluginInstallRecoveryJournal
    implements PluginInstallJournal {
  Future<bool> compareAndSet({
    required String operationId,
    required PluginInstallJournalStatus expectedStatus,
    required DateTime expectedUpdatedAt,
    required PluginInstallJournalEntry replacement,
  });
}

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
  final int fencingToken;

  const PluginInstallStaging({
    required this.operationId,
    required this.pluginId,
    required this.opaqueHandle,
    this.fencingToken = 0,
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
    int fencingToken = 0,
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
  manuallyReconciled,
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
  final int? fencingToken;

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
    this.fencingToken,
  });
}

abstract interface class PluginInstallJournal {
  /// When [entry.fencingToken] is non-null, production implementations must
  /// atomically persist the highest accepted token per operation and reject
  /// any lower token. This check must be part of the journal write transaction.
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


/// Marker for journals that enforce the fencing token on every write.
///
/// The token is carried by [PluginInstallJournalEntry.fencingToken]. A fenced
/// implementation must reject stale tokens atomically with its write.
abstract interface class FencedPluginInstallJournal
    implements PluginInstallJournal {
  /// Atomically advances the highest accepted token before work begins.
  /// Returns false if a newer token has already been registered.
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  });
}

/// Marker for filesystem adapters that enforce [PluginInstallStaging.fencingToken]
/// on every mutating operation, including extraction, promotion, rollback,
/// finalization and staging cleanup. The highest token must be persisted in
/// operation-owned metadata and lower tokens rejected.
abstract interface class FencedPluginInstallFileSystem
    implements PluginInstallFileSystem {
  /// Atomically persists the highest accepted token in operation-owned state.
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  });
}

/// Installed-record adapter that atomically rejects stale operation tokens.
abstract interface class FencedTransactionalInstalledPluginStore
    implements TransactionalInstalledPluginStore {
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  });

  Future<bool> createIfAbsentFenced(
    InstalledPluginRecord plugin, {
    required String operationId,
    required int fencingToken,
  });

  Future<bool> removeIfMatchesFenced(
    InstalledPluginRecord plugin, {
    required String operationId,
    required int fencingToken,
  });
}


/// Recovery journal that atomically enforces fencing tokens on both writes
/// and compare-and-set claims.
abstract interface class FencedPluginInstallRecoveryJournal
    implements PluginInstallRecoveryJournal, FencedPluginInstallJournal {}


/// Operator's verified conclusion after inspecting an ambiguous installation.
///
/// These values describe observed state; recording one never performs a
/// filesystem or installed-record mutation.
enum PluginInstallManualResolution {
  installedAndVerified,
  absentAndClean,
  residualStateAccepted,
}

/// Append-only evidence for a host-controlled manual reconciliation.
final class PluginInstallManualReconciliation {
  final String operationId;
  final String pluginId;
  final String version;
  final PluginInstallManualResolution resolution;
  final String resolutionId;
  final String operatorId;
  final String evidenceSummary;
  final DateTime resolvedAt;

  const PluginInstallManualReconciliation({
    required this.operationId,
    required this.pluginId,
    required this.version,
    required this.resolution,
    required this.resolutionId,
    required this.operatorId,
    required this.evidenceSummary,
    required this.resolvedAt,
  });
}

/// Durable, compare-and-set manual closure for ambiguous recovery operations.
///
/// Implementations must atomically append the audit record and advance the
/// journal projection to [PluginInstallJournalStatus.manuallyReconciled].
/// This operation records an operator conclusion only; it must not mutate
/// filesystem contents or installed-plugin records.
abstract interface class PluginInstallManualReconciliationStore {
  Future<bool> reconcileManually({
    required String operationId,
    required DateTime expectedUpdatedAt,
    required PluginInstallManualResolution resolution,
    required String resolutionId,
    required String operatorId,
    required String evidenceSummary,
    required DateTime resolvedAt,
  });

  Future<List<PluginInstallManualReconciliation>> manualReconciliations(
    String operationId,
  );
}

/// Bounded filters for installation audit history.
///
/// [from] is inclusive and [to] is exclusive. The default page is 100 rows;
/// adapters must reject limits outside 1..500 and offsets outside 0..100000.
final class PluginInstallAuditQuery {
  final String? operationId;
  final String? pluginId;
  final PluginInstallJournalStatus? status;
  final String? operatorId;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final int offset;

  const PluginInstallAuditQuery({
    this.operationId,
    this.pluginId,
    this.status,
    this.operatorId,
    this.from,
    this.to,
    this.limit = 100,
    this.offset = 0,
  });
}

/// Safe-to-display summary of one durable installation transition.
///
/// Filesystem paths, staging handles, content hashes and package contents are
/// intentionally excluded. Manual evidence summaries are optional and should
/// reference protected incident records rather than contain secrets.
final class PluginInstallAuditRecord {
  final int eventId;
  final String operationId;
  final String pluginId;
  final String version;
  final PluginInstallJournalStatus status;
  final DateTime occurredAt;
  final int revision;
  final String? operatorId;
  final String? approvalId;
  final String? failureCode;
  final int? fencingToken;
  final PluginInstallManualResolution? manualResolution;
  final String? evidenceSummary;

  const PluginInstallAuditRecord({
    required this.eventId,
    required this.operationId,
    required this.pluginId,
    required this.version,
    required this.status,
    required this.occurredAt,
    required this.revision,
    this.operatorId,
    this.approvalId,
    this.failureCode,
    this.fencingToken,
    this.manualResolution,
    this.evidenceSummary,
  });
}

/// Read-only, bounded access to the append-only installation transition log.
abstract interface class PluginInstallAuditStore {
  Future<List<PluginInstallAuditRecord>> queryAudit(
    PluginInstallAuditQuery query,
  );
}



/// A bounded set of terminal-operation audit records offered for archival.
final class PluginInstallAuditArchiveBatch {
  final String batchId;
  final DateTime createdAt;
  final DateTime cutoff;
  final List<PluginInstallAuditRecord> records;

  PluginInstallAuditArchiveBatch({
    required this.batchId,
    required this.createdAt,
    required this.cutoff,
    required List<PluginInstallAuditRecord> records,
  }) : records = List.unmodifiable(records);
}

/// Proof returned only after an archive adapter has durably stored and verified
/// the complete batch. [eventIds] identifies the exact local rows eligible for
/// deletion; [digest] is the archive adapter's integrity digest/signature.
final class PluginInstallAuditArchiveReceipt {
  final String archiveId;
  final String batchId;
  final String digest;
  final int recordCount;
  final List<int> eventIds;
  final DateTime cutoff;
  final DateTime archivedAt;

  PluginInstallAuditArchiveReceipt({
    required this.archiveId,
    required this.batchId,
    required this.digest,
    required this.recordCount,
    required List<int> eventIds,
    required this.cutoff,
    required this.archivedAt,
  }) : eventIds = List.unmodifiable(eventIds);
}

/// Host-owned archive boundary. Implementations must persist the complete
/// batch before returning and verify its durable bytes before issuing receipt.
abstract interface class PluginInstallAuditArchiveStore {
  Future<PluginInstallAuditArchiveReceipt> archiveAndVerify(
    PluginInstallAuditArchiveBatch batch,
  );

  Future<bool> verify(PluginInstallAuditArchiveReceipt receipt);
}

/// Retention operations never select active or ambiguous operations for purge.
/// The host must archive and verify a previewed batch before pruning it.
abstract interface class PluginInstallAuditRetentionStore {
  Future<List<PluginInstallAuditRecord>> previewPrunableAudit({
    required DateTime before,
    int limit = 500,
  });

  Future<int> pruneArchivedAudit({
    required PluginInstallAuditArchiveReceipt receipt,
    required PluginInstallAuditArchiveStore archiveStore,
  });
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'plugin_install_recovery_planner.dart';

/// Failure raised when an approved installation recovery cannot be completed.
final class PluginInstallRecoveryException implements Exception {
  final String code;
  final String message;
  final bool reconciliationRequired;

  const PluginInstallRecoveryException(
    this.code,
    this.message, {
    this.reconciliationRequired = false,
  });

  @override
  String toString() => 'PluginInstallRecoveryException($code): $message';
}

/// Executes exactly the action in a fresh finding after explicit host approval.
///
/// The host must pass a stable operator identity and unique approval ID. The
/// executor re-inspects filesystem and metadata state and atomically claims
/// the journal entry before any recovery side effect.
final class PluginInstallRecoveryExecutor {
  final PluginInstallRecoveryJournal journal;
  final PluginInstallFileSystem fileSystem;
  final InstalledPluginStore installedStore;
  final DateTime Function() clock;

  PluginInstallRecoveryExecutor({
    required this.journal,
    required this.fileSystem,
    required this.installedStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginInstallJournalEntry> execute(
    PluginInstallRecoveryFinding finding, {
    required String approvedBy,
    required String approvalId,
  }) async {
    if (approvedBy.trim().isEmpty || approvalId.trim().isEmpty) {
      throw ArgumentError('Recovery requires an operator identity and approval ID.');
    }
    if (finding.action == PluginInstallRecoveryAction.manualReview) {
      throw const PluginInstallRecoveryException(
        'MANUAL_REVIEW_REQUIRED',
        'This finding has no safe automated recovery action.',
      );
    }

    final entry = finding.journalEntry;
    final current = await journal.unresolved();
    final latest = current.where((item) => item.operationId == entry.operationId);
    if (latest.length != 1 || !_sameJournal(latest.single, entry)) {
      throw const PluginInstallRecoveryException(
        'STALE_RECOVERY_PLAN',
        'The installation journal changed after inspection. Re-plan before approval.',
      );
    }

    final freshFilesystem = await fileSystem.inspectOperation(
      operationId: entry.operationId,
      pluginId: entry.pluginId,
      stagingHandle: entry.stagingHandle,
      destinationPath: entry.promotedPath,
    );
    final freshRecord = await installedStore.find(entry.pluginId);
    final freshRecordMatches = freshRecord != null &&
        freshRecord.version.toString() == entry.version &&
        entry.contentHash != null &&
        freshRecord.contentHash == entry.contentHash &&
        entry.promotedPath != null &&
        freshRecord.installPath == entry.promotedPath;
    if (freshFilesystem != finding.filesystem ||
        (freshRecord != null) != finding.installedRecordExists ||
        freshRecordMatches != finding.installedRecordMatches) {
      throw const PluginInstallRecoveryException(
        'STALE_RECOVERY_EVIDENCE',
        'Filesystem or installed metadata changed after inspection. Re-plan before approval.',
      );
    }

    final claimed = _entry(
      entry,
      status: PluginInstallJournalStatus.recoveryStarted,
      failureCode: 'RECOVERY_APPROVED',
    );
    final didClaim = await journal.compareAndSet(
      operationId: entry.operationId,
      expectedStatus: entry.status,
      replacement: claimed,
    );
    if (!didClaim) {
      throw const PluginInstallRecoveryException(
        'RECOVERY_CLAIM_CONFLICT',
        'Another recovery worker changed or claimed this operation.',
      );
    }

    try {
      final staging = entry.stagingHandle == null
          ? null
          : PluginInstallStaging(
              operationId: entry.operationId,
              pluginId: entry.pluginId,
              opaqueHandle: entry.stagingHandle!,
            );
      switch (finding.action) {
        case PluginInstallRecoveryAction.discardStaging:
          if (staging == null) {
            throw const PluginInstallRecoveryException(
              'STAGING_HANDLE_MISSING',
              'The journal does not contain a staging handle.',
              reconciliationRequired: true,
            );
          }
          await fileSystem.discardStaging(staging);
          break;
        case PluginInstallRecoveryAction.rollbackPromotion:
          if (staging == null || entry.promotedPath == null) {
            throw const PluginInstallRecoveryException(
              'ROLLBACK_METADATA_MISSING',
              'Promotion rollback requires staging and destination metadata.',
              reconciliationRequired: true,
            );
          }
          await fileSystem.rollbackPromotion(
            staging,
            promotedPath: entry.promotedPath!,
          );
          break;
        case PluginInstallRecoveryAction.finalizePromotion:
          if (staging == null || entry.promotedPath == null) {
            throw const PluginInstallRecoveryException(
              'FINALIZE_METADATA_MISSING',
              'Promotion finalization requires staging and destination metadata.',
              reconciliationRequired: true,
            );
          }
          await fileSystem.finalizePromotion(
            staging,
            promotedPath: entry.promotedPath!,
          );
          break;
        case PluginInstallRecoveryAction.markFailed:
          break;
        case PluginInstallRecoveryAction.manualReview:
          throw StateError('Manual-review action cannot be executed.');
      }

      final terminalStatus = switch (finding.action) {
        PluginInstallRecoveryAction.finalizePromotion =>
          PluginInstallJournalStatus.committed,
        PluginInstallRecoveryAction.markFailed =>
          PluginInstallJournalStatus.failed,
        _ => PluginInstallJournalStatus.rolledBack,
      };
      final completed = _entry(
        entry,
        status: terminalStatus,
        failureCode: 'RECOVERED_BY_HOST',
      );
      final saved = await journal.compareAndSet(
        operationId: entry.operationId,
        expectedStatus: PluginInstallJournalStatus.recoveryStarted,
        replacement: completed,
      );
      if (!saved) {
        throw const PluginInstallRecoveryException(
          'RECOVERY_OUTCOME_NOT_RECORDED',
          'Recovery side effect completed but the journal outcome was not saved.',
          reconciliationRequired: true,
        );
      }
      return completed;
    } catch (error) {
      try {
        await journal.compareAndSet(
          operationId: entry.operationId,
          expectedStatus: PluginInstallJournalStatus.recoveryStarted,
          replacement: _entry(
            entry,
            status: PluginInstallJournalStatus.needsReconciliation,
            failureCode: error is PluginInstallRecoveryException
                ? error.code
                : 'RECOVERY_SIDE_EFFECT_FAILED',
          ),
        );
      } catch (_) {
        // The recoveryStarted claim remains the durable ambiguity marker.
      }
      if (error is PluginInstallRecoveryException) rethrow;
      throw const PluginInstallRecoveryException(
        'RECOVERY_SIDE_EFFECT_FAILED',
        'An approved recovery operation failed; manual reconciliation is required.',
        reconciliationRequired: true,
      );
    }
  }

  PluginInstallJournalEntry _entry(
    PluginInstallJournalEntry source, {
    required PluginInstallJournalStatus status,
    required String failureCode,
  }) =>
      PluginInstallJournalEntry(
        operationId: source.operationId,
        pluginId: source.pluginId,
        version: source.version,
        status: status,
        updatedAt: clock().toUtc(),
        stagingHandle: source.stagingHandle,
        promotedPath: source.promotedPath,
        failureCode: failureCode,
        contentHash: source.contentHash,
      );

  bool _sameJournal(
    PluginInstallJournalEntry left,
    PluginInstallJournalEntry right,
  ) =>
      left.operationId == right.operationId &&
      left.pluginId == right.pluginId &&
      left.version == right.version &&
      left.status == right.status &&
      left.updatedAt == right.updatedAt &&
      left.stagingHandle == right.stagingHandle &&
      left.promotedPath == right.promotedPath &&
      left.contentHash == right.contentHash &&
      left.failureCode == right.failureCode;
}

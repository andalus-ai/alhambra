import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Side-effect-free action recommended for one interrupted installation.
enum PluginInstallRecoveryAction {
  discardStaging,
  rollbackPromotion,
  finalizePromotion,
  markFailed,
  manualReview,
}

/// Immutable inspection finding. It is a proposal, never authorization.
final class PluginInstallRecoveryFinding {
  final PluginInstallJournalEntry journalEntry;
  final PluginInstallRecoverySnapshot filesystem;
  final bool installedRecordExists;
  final bool installedRecordMatches;
  final PluginInstallRecoveryAction action;
  final String guidance;

  const PluginInstallRecoveryFinding({
    required this.journalEntry,
    required this.filesystem,
    required this.installedRecordExists,
    required this.installedRecordMatches,
    required this.action,
    required this.guidance,
  });

  String get operationId => journalEntry.operationId;
  String get pluginId => journalEntry.pluginId;
  bool get requiresHostApproval =>
      action != PluginInstallRecoveryAction.manualReview;
  bool get isAutomaticallyExecutable => false;
}

/// Immutable output from a read-only scan of unresolved installation records.
final class PluginInstallRecoveryReport {
  final DateTime inspectedAt;
  final List<PluginInstallRecoveryFinding> findings;

  PluginInstallRecoveryReport({
    required this.inspectedAt,
    required Iterable<PluginInstallRecoveryFinding> findings,
  }) : findings = List.unmodifiable(findings);

  List<PluginInstallRecoveryFinding> get requiringHostAction =>
      List.unmodifiable(findings.where(
        (finding) => finding.action != PluginInstallRecoveryAction.manualReview,
      ));

  List<PluginInstallRecoveryFinding> get requiringManualReview =>
      List.unmodifiable(findings.where(
        (finding) => finding.action == PluginInstallRecoveryAction.manualReview,
      ));
}

/// Read-only reconciler for interrupted package installation operations.
///
/// The planner never deletes staging data, rolls back/promotes files, mutates
/// installed records, or updates journal entries. Every proposed action still
/// requires a separate host approval and a fresh inspection at execution time.
final class PluginInstallRecoveryPlanner {
  final PluginInstallJournal journal;
  final PluginInstallFileSystem fileSystem;
  final InstalledPluginStore installedStore;
  final DateTime Function() clock;

  PluginInstallRecoveryPlanner({
    required this.journal,
    required this.fileSystem,
    required this.installedStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginInstallRecoveryReport> inspect() async {
    final entries = await journal.unresolved();
    final findings = <PluginInstallRecoveryFinding>[];
    final operationIds = <String>{};

    for (final entry in entries) {
      if (entry.operationId.trim().isEmpty ||
          entry.pluginId.trim().isEmpty ||
          entry.version.trim().isEmpty) {
        throw StateError('Install journal contains an entry with an empty identity.');
      }
      if (!operationIds.add(entry.operationId)) {
        throw StateError(
          'Install journal returned multiple unresolved entries for operation "${entry.operationId}".',
        );
      }

      final filesystem = await fileSystem.inspectOperation(
        operationId: entry.operationId,
        pluginId: entry.pluginId,
        stagingHandle: entry.stagingHandle,
        destinationPath: entry.promotedPath,
      );
      final installed = await installedStore.find(entry.pluginId);
      final recordMatches = installed != null &&
          installed.id == entry.pluginId &&
          installed.version.toString() == entry.version &&
          entry.contentHash != null &&
          installed.contentHash == entry.contentHash &&
          entry.promotedPath != null &&
          installed.installPath == entry.promotedPath;

      final classified = _classify(
        entry: entry,
        filesystem: filesystem,
        installedRecordExists: installed != null,
        installedRecordMatches: recordMatches,
      );
      findings.add(PluginInstallRecoveryFinding(
        journalEntry: entry,
        filesystem: filesystem,
        installedRecordExists: installed != null,
        installedRecordMatches: recordMatches,
        action: classified.$1,
        guidance: classified.$2,
      ));
    }

    findings.sort((a, b) {
      final byPlugin = a.pluginId.compareTo(b.pluginId);
      return byPlugin != 0 ? byPlugin : a.operationId.compareTo(b.operationId);
    });
    return PluginInstallRecoveryReport(
      inspectedAt: clock().toUtc(),
      findings: findings,
    );
  }

  (PluginInstallRecoveryAction, String) _classify({
    required PluginInstallJournalEntry entry,
    required PluginInstallRecoverySnapshot filesystem,
    required bool installedRecordExists,
    required bool installedRecordMatches,
  }) {
    if (entry.status == PluginInstallJournalStatus.recoveryStarted ||
        entry.status == PluginInstallJournalStatus.needsReconciliation) {
      return (
        PluginInstallRecoveryAction.manualReview,
        'A previous recovery attempt may have performed a side effect. Inspect '
            'the filesystem and journal history before authorizing another action.',
      );
    }

    if (entry.contentHash == null || entry.contentHash!.trim().isEmpty) {
      return (
        PluginInstallRecoveryAction.manualReview,
        'The journal does not contain a content hash; installed metadata cannot '
            'be safely correlated with this operation.',
      );
    }

    if (installedRecordExists && !installedRecordMatches) {
      return (
        PluginInstallRecoveryAction.manualReview,
        'An installed record exists but does not match this operation. Do not '
            'remove or overwrite another installation.',
      );
    }

    if (filesystem.destinationExists &&
        !filesystem.destinationOwnedByOperation) {
      return (
        PluginInstallRecoveryAction.manualReview,
        'The destination exists but the filesystem adapter cannot prove that '
            'this operation owns it.',
      );
    }

    if (filesystem.destinationExists && installedRecordMatches) {
      if (entry.stagingHandle == null || entry.promotedPath == null) {
        return (
          PluginInstallRecoveryAction.manualReview,
          'The journal is missing staging or destination metadata required to finalize promotion.',
        );
      }
      return (
        PluginInstallRecoveryAction.finalizePromotion,
        'The destination and installed record agree. Finalize the reversible '
            'promotion and commit the journal.',
      );
    }

    if (filesystem.destinationExists &&
        !installedRecordExists &&
        filesystem.rollbackAvailable) {
      if (entry.stagingHandle == null || entry.promotedPath == null) {
        return (
          PluginInstallRecoveryAction.manualReview,
          'The journal is missing staging or destination metadata required to roll back promotion.',
        );
      }
      return (
        PluginInstallRecoveryAction.rollbackPromotion,
        'The destination belongs to this operation but no installed record '
            'was committed. Roll back the promoted tree.',
      );
    }

    if (filesystem.stagingExists &&
        !filesystem.destinationExists &&
        !installedRecordExists) {
      if (entry.stagingHandle == null) {
        return (
          PluginInstallRecoveryAction.manualReview,
          'The staging handle is missing; the adapter must not guess which staging area to remove.',
        );
      }
      return (
        PluginInstallRecoveryAction.discardStaging,
        'Only private staging remains. Discard it and close the interrupted install.',
      );
    }

    if (!filesystem.stagingExists &&
        !filesystem.destinationExists &&
        !installedRecordExists &&
        (entry.status == PluginInstallJournalStatus.verificationStarted ||
            entry.status == PluginInstallJournalStatus.verified)) {
      return (
        PluginInstallRecoveryAction.markFailed,
        'No installation side effects are present. Mark the interrupted '
            'pre-install operation as failed.',
      );
    }

    return (
      PluginInstallRecoveryAction.manualReview,
      'Filesystem and installed-record evidence do not match a safe recovery '
          'case. Resolve the state with host-specific inspection.',
    );
  }
}

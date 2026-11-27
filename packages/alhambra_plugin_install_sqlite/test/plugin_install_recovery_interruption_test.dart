import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_filesystem/alhambra_plugin_install_filesystem.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fault-injection boundary: the recovery claim can be persisted, but the
/// terminal outcome and reconciliation marker cannot be committed.
final class _UnavailableOutcomeJournal
    implements FencedPluginInstallRecoveryJournal {
  final SqlitePluginInstallJournal delegate;

  _UnavailableOutcomeJournal(this.delegate);

  @override
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  }) =>
      delegate.advanceFence(
        operationId: operationId,
        fencingToken: fencingToken,
      );

  @override
  Future<bool> compareAndSet({
    required String operationId,
    required PluginInstallJournalStatus expectedStatus,
    required DateTime expectedUpdatedAt,
    required PluginInstallJournalEntry replacement,
  }) {
    if (replacement.status == PluginInstallJournalStatus.rolledBack ||
        replacement.status == PluginInstallJournalStatus.committed ||
        replacement.status == PluginInstallJournalStatus.needsReconciliation) {
      throw StateError('Injected journal outage at recovery outcome boundary.');
    }
    return delegate.compareAndSet(
      operationId: operationId,
      expectedStatus: expectedStatus,
      expectedUpdatedAt: expectedUpdatedAt,
      replacement: replacement,
    );
  }

  @override
  Future<void> write(PluginInstallJournalEntry entry) => delegate.write(entry);

  @override
  Future<List<PluginInstallJournalEntry>> unresolved() => delegate.unresolved();
}

void main() {
  test('restart after recovery side effect remains manual-review only', () async {
    final directory = await Directory.systemTemp.createTemp(
      'alhambra-recovery-interruption-',
    );
    final installRoot = await Directory('${directory.path}/install').create();
    final databasePath = '${directory.path}/install.sqlite';

    var journal = SqlitePluginInstallJournal(databasePath);
    var leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    var installedStore = SqliteInstalledPluginStore(databasePath);
    var fileSystem =
        LocalPluginInstallFileSystem(rootDirectory: installRoot);

    addTearDown(() async {
      journal.close();
      leases.close();
      installedStore.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    const operationId = 'install-recovery-outcome-interruption';
    const pluginId = 'example.recovery-interruption';
    const version = '1.0.0';
    const contentHash =
        'sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    final startedAt = DateTime.utc(2026, 11, 20, 2);

    final installerLease = await leases.acquire(
      operationId: operationId,
      ownerId: 'installer-worker',
      now: startedAt,
      leaseDuration: const Duration(seconds: 1),
    );
    expect(installerLease, isNotNull);
    expect(installerLease!.fencingToken, 1);

    expect(await journal.advanceFence(
      operationId: operationId,
      fencingToken: installerLease.fencingToken,
    ), isTrue);
    expect(await fileSystem.advanceFence(
      operationId: operationId,
      fencingToken: installerLease.fencingToken,
    ), isTrue);
    expect(await installedStore.advanceFence(
      operationId: operationId,
      fencingToken: installerLease.fencingToken,
    ), isTrue);

    final staging = await fileSystem.createStaging(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      fencingToken: installerLease.fencingToken,
    );
    await fileSystem.writeFile(
      staging: staging,
      relativePath: 'lib/main.dart',
      bytes: Stream<List<int>>.value([1, 2, 3]),
      maxBytes: 16,
    );
    final destination = await fileSystem.destinationPathFor(
      pluginId: pluginId,
      version: version,
    );
    await journal.write(PluginInstallJournalEntry(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      status: PluginInstallJournalStatus.promoting,
      updatedAt: startedAt,
      stagingHandle: staging.opaqueHandle,
      promotedPath: destination,
      contentHash: contentHash,
      fencingToken: installerLease.fencingToken,
    ));
    await fileSystem.promote(staging, destinationPath: destination);
    expect(await Directory(destination).exists(), isTrue);

    var clockValue = startedAt.add(const Duration(seconds: 2));
    DateTime advancingClock() {
      final current = clockValue;
      clockValue = clockValue.add(const Duration(milliseconds: 1));
      return current;
    }

    final report = await PluginInstallRecoveryPlanner(
      journal: journal,
      fileSystem: fileSystem,
      installedStore: installedStore,
      clock: advancingClock,
    ).inspect();
    expect(report.findings, hasLength(1));
    final finding = report.findings.single;
    expect(finding.action, PluginInstallRecoveryAction.rollbackPromotion);

    // The executor persists recoveryStarted, performs the rollback, then
    // encounters a journal outage before either terminal state can be saved.
    await expectLater(
      PluginInstallRecoveryExecutor(
        journal: _UnavailableOutcomeJournal(journal),
        fileSystem: fileSystem,
        installedStore: installedStore,
        leaseStore: leases,
        workerId: 'recovery-worker',
        clock: advancingClock,
      ).execute(
        finding,
        approvedBy: 'test-operator',
        approvalId: 'approval-recovery-outcome-interruption',
      ),
      throwsA(isA<PluginInstallRecoveryException>()),
    );

    expect(await Directory(destination).exists(), isFalse);
    final claimed = await journal.read(operationId);
    expect(claimed?.status, PluginInstallJournalStatus.recoveryStarted);
    expect(claimed?.approvedBy, 'test-operator');
    expect(claimed?.approvalId, 'approval-recovery-outcome-interruption');

    // Simulate process restart and inspect only with reopened durable adapters.
    journal.close();
    leases.close();
    installedStore.close();
    journal = SqlitePluginInstallJournal(databasePath);
    leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    installedStore = SqliteInstalledPluginStore(databasePath);
    fileSystem = LocalPluginInstallFileSystem(rootDirectory: installRoot);

    final restartedReport = await PluginInstallRecoveryPlanner(
      journal: journal,
      fileSystem: fileSystem,
      installedStore: installedStore,
      clock: advancingClock,
    ).inspect();
    expect(restartedReport.findings, hasLength(1));
    final restartedFinding = restartedReport.findings.single;
    expect(
      restartedFinding.action,
      PluginInstallRecoveryAction.manualReview,
    );
    expect(restartedFinding.requiresHostApproval, isFalse);

    await expectLater(
      PluginInstallRecoveryExecutor(
        journal: journal,
        fileSystem: fileSystem,
        installedStore: installedStore,
        clock: advancingClock,
      ).execute(
        restartedFinding,
        approvedBy: 'second-operator',
        approvalId: 'approval-must-not-replay',
      ),
      throwsA(
        isA<PluginInstallRecoveryException>().having(
          (error) => error.code,
          'code',
          'MANUAL_REVIEW_REQUIRED',
        ),
      ),
    );

    expect(await Directory(destination).exists(), isFalse);
    expect(
      (await journal.read(operationId))?.status,
      PluginInstallJournalStatus.recoveryStarted,
    );
    expect(await journal.history(operationId), hasLength(2));
  });
}

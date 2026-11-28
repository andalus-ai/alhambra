import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('SQLite manual recovery reconciliation', () {
    test('adds the reconciliation audit table to an existing schema-v2 DB',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-manual-reconcile-v2-');
      final path = '${directory.path}/install.sqlite';
      final legacy = sq.sqlite3.open(path);
      legacy.execute('''
        CREATE TABLE plugin_install_operation (
          operation_id TEXT PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          plugin_id TEXT NOT NULL,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          revision INTEGER NOT NULL CHECK (revision >= 1),
          updated_at TEXT NOT NULL,
          staging_handle TEXT,
          promoted_path TEXT,
          failure_code TEXT,
          content_hash TEXT,
          approved_by TEXT,
          approval_id TEXT
        )
      ''');
      legacy.execute('''
        CREATE TABLE plugin_install_approval (
          approval_id TEXT PRIMARY KEY,
          operation_id TEXT NOT NULL,
          approved_by TEXT NOT NULL,
          recorded_at TEXT NOT NULL,
          FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
        )
      ''');
      legacy.execute('''
        CREATE TABLE plugin_install_event (
          event_id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_id TEXT NOT NULL,
          revision INTEGER NOT NULL,
          schema_version INTEGER NOT NULL,
          plugin_id TEXT NOT NULL,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          staging_handle TEXT,
          promoted_path TEXT,
          failure_code TEXT,
          content_hash TEXT,
          approved_by TEXT,
          approval_id TEXT,
          UNIQUE(operation_id, revision),
          FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
        )
      ''');
      legacy.execute('CREATE INDEX idx_plugin_install_event_history ON plugin_install_event(operation_id, revision)');
      legacy.execute('''
        CREATE TABLE plugin_install_fence (
          operation_id TEXT PRIMARY KEY,
          highest_token INTEGER NOT NULL CHECK (highest_token >= 0)
        )
      ''');
      legacy.execute('PRAGMA user_version = 2');
      legacy.dispose();

      final journal = SqlitePluginInstallJournal(path);
      addTearDown(() async {
        journal.close();
        await directory.delete(recursive: true);
      });
      expect(await journal.manualReconciliations('legacy-operation'), isEmpty);
      expect(await journal.queryAudit(const PluginInstallAuditQuery()), isEmpty);
      expect(await journal.previewPrunableAudit(
        before: DateTime.utc(2030),
      ), isEmpty);
    });

    test('records an atomic, durable operator resolution and closes operation',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-manual-reconcile-');
      final path = '${directory.path}/install.sqlite';
      var journal = SqlitePluginInstallJournal(path);
      addTearDown(() async {
        journal.close();
        await directory.delete(recursive: true);
      });

      const operationId = 'install-manual-reconcile';
      final claimedAt = DateTime.utc(2026, 11, 27, 10);
      final resolvedAt = claimedAt.add(const Duration(minutes: 5));
      expect(await journal.advanceFence(
        operationId: operationId,
        fencingToken: 4,
      ), isTrue);
      await journal.write(PluginInstallJournalEntry(
        operationId: operationId,
        pluginId: 'example.manual',
        version: '1.2.3',
        status: PluginInstallJournalStatus.recoveryStarted,
        updatedAt: claimedAt,
        failureCode: 'RECOVERY_APPROVED',
        approvedBy: 'recovery-worker',
        approvalId: 'initial-recovery-approval',
        contentHash:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        fencingToken: 4,
      ));

      expect(await journal.reconcileManually(
        operationId: operationId,
        expectedUpdatedAt: claimedAt,
        resolution: PluginInstallManualResolution.absentAndClean,
        resolutionId: 'manual-resolution-001',
        operatorId: 'host-operator',
        evidenceSummary:
            'Verified destination absent, staging absent, and installed record absent.',
        resolvedAt: resolvedAt,
      ), isTrue);

      final reconciled = await journal.read(operationId);
      expect(reconciled?.status,
          PluginInstallJournalStatus.manuallyReconciled);
      expect(reconciled?.approvedBy, 'host-operator');
      expect(reconciled?.approvalId, 'manual-resolution-001');
      expect(reconciled?.failureCode,
          'MANUAL_RECONCILED_ABSENTANDCLEAN');
      expect(await journal.unresolved(), isEmpty);
      expect((await journal.history(operationId)).last.status,
          PluginInstallJournalStatus.manuallyReconciled);

      final audit = await journal.manualReconciliations(operationId);
      expect(audit, hasLength(1));
      expect(audit.single.resolution,
          PluginInstallManualResolution.absentAndClean);
      expect(audit.single.operatorId, 'host-operator');
      expect(audit.single.evidenceSummary,
          contains('destination absent'));

      // The resolution is a one-way, compare-and-set closure. It cannot be
      // submitted again against the old recovery claim.
      expect(await journal.reconcileManually(
        operationId: operationId,
        expectedUpdatedAt: claimedAt,
        resolution: PluginInstallManualResolution.absentAndClean,
        resolutionId: 'manual-resolution-duplicate',
        operatorId: 'second-operator',
        evidenceSummary: 'duplicate',
        resolvedAt: resolvedAt.add(const Duration(minutes: 1)),
      ), isFalse);

      journal.close();
      journal = SqlitePluginInstallJournal(path);
      expect((await journal.read(operationId))?.status,
          PluginInstallJournalStatus.manuallyReconciled);
      expect(await journal.manualReconciliations(operationId), hasLength(1));
      expect(await journal.unresolved(), isEmpty);
    });

    test('rejects reconciliation from a stale fencing token', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      const operationId = 'install-manual-reconcile-fence';
      final claimedAt = DateTime.utc(2026, 11, 27, 12);
      expect(await journal.advanceFence(
        operationId: operationId,
        fencingToken: 8,
      ), isTrue);
      await journal.write(PluginInstallJournalEntry(
        operationId: operationId,
        pluginId: 'example.manual.fence',
        version: '1.0.0',
        status: PluginInstallJournalStatus.recoveryStarted,
        updatedAt: claimedAt,
        fencingToken: 8,
      ));
      expect(await journal.advanceFence(
        operationId: operationId,
        fencingToken: 9,
      ), isTrue);
      await expectLater(
        journal.reconcileManually(
          operationId: operationId,
          expectedUpdatedAt: claimedAt,
          resolution: PluginInstallManualResolution.residualStateAccepted,
          resolutionId: 'manual-resolution-stale-fence',
          operatorId: 'host-operator',
          evidenceSummary: 'Reviewed after a newer worker took ownership.',
          resolvedAt: claimedAt.add(const Duration(minutes: 1)),
        ),
        throwsStateError,
      );
      expect((await journal.read(operationId))?.status,
          PluginInstallJournalStatus.recoveryStarted);
      expect(await journal.manualReconciliations(operationId), isEmpty);
    });

    test('rejects stale timestamps and invalid evidence without mutation',
        () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      const operationId = 'install-manual-reconcile-cas';
      final claimedAt = DateTime.utc(2026, 11, 27, 11);
      await journal.write(PluginInstallJournalEntry(
        operationId: operationId,
        pluginId: 'example.manual.cas',
        version: '1.0.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: claimedAt,
      ));

      expect(await journal.reconcileManually(
        operationId: operationId,
        expectedUpdatedAt: claimedAt.subtract(const Duration(seconds: 1)),
        resolution: PluginInstallManualResolution.residualStateAccepted,
        resolutionId: 'manual-resolution-stale',
        operatorId: 'host-operator',
        evidenceSummary: 'Reviewed residual state.',
        resolvedAt: claimedAt.add(const Duration(minutes: 1)),
      ), isFalse);
      await expectLater(
        journal.reconcileManually(
          operationId: operationId,
          expectedUpdatedAt: claimedAt,
          resolution: PluginInstallManualResolution.residualStateAccepted,
          resolutionId: 'manual-resolution-invalid',
          operatorId: 'host-operator',
          evidenceSummary: 'contains\ncontrol character',
          resolvedAt: claimedAt.add(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
      expect((await journal.read(operationId))?.status,
          PluginInstallJournalStatus.needsReconciliation);
      expect(await journal.manualReconciliations(operationId), isEmpty);
    });
  });
}

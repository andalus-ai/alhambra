import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SQLite plugin installation audit query', () {
    test('queries bounded, newest-first transition pages with filters', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);

      final t0 = DateTime.utc(2026, 11, 28, 9);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op-a',
        pluginId: 'example.alpha',
        version: '1.0.0',
        status: PluginInstallJournalStatus.verificationStarted,
        updatedAt: t0,
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op-a',
        pluginId: 'example.alpha',
        version: '1.0.0',
        status: PluginInstallJournalStatus.verified,
        updatedAt: t0.add(const Duration(minutes: 1)),
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op-b',
        pluginId: 'example.beta',
        version: '2.0.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: t0.add(const Duration(minutes: 2)),
      ));

      final all = await journal.queryAudit(const PluginInstallAuditQuery());
      expect(all.map((event) => event.operationId),
          ['op-b', 'op-a', 'op-a']);
      expect(all.map((event) => event.revision), [1, 2, 1]);

      final filtered = await journal.queryAudit(PluginInstallAuditQuery(
        pluginId: 'example.alpha',
        from: t0,
        to: t0.add(const Duration(minutes: 2)),
        limit: 1,
      ));
      expect(filtered, hasLength(1));
      expect(filtered.single.status, PluginInstallJournalStatus.verified);

      final nextPage = await journal.queryAudit(const PluginInstallAuditQuery(
        pluginId: 'example.alpha',
        limit: 1,
        offset: 1,
      ));
      expect(nextPage.single.status,
          PluginInstallJournalStatus.verificationStarted);

      final operation = await journal.queryAudit(
        const PluginInstallAuditQuery(operationId: 'op-b'),
      );
      expect(operation.single.pluginId, 'example.beta');
    });

    test('includes manual resolution metadata without exposing filesystem data',
        () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final startedAt = DateTime.utc(2026, 11, 28, 10);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op-manual',
        pluginId: 'example.manual',
        version: '3.1.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: startedAt,
        stagingHandle: '/private/staging/handle',
        promotedPath: '/private/plugins/example',
        contentHash: 'sha256:private-hash',
      ));
      await journal.reconcileManually(
        operationId: 'op-manual',
        expectedUpdatedAt: startedAt,
        resolution: PluginInstallManualResolution.installedAndVerified,
        resolutionId: 'resolution-123',
        operatorId: 'operator-7',
        evidenceSummary: 'Evidence stored in incident INC-7.',
        resolvedAt: startedAt.add(const Duration(minutes: 1)),
      );

      final records = await journal.queryAudit(const PluginInstallAuditQuery(
        operationId: 'op-manual',
        status: PluginInstallJournalStatus.manuallyReconciled,
        operatorId: 'operator-7',
      ));
      expect(records, hasLength(1));
      expect(records.single.manualResolution,
          PluginInstallManualResolution.installedAndVerified);
      expect(records.single.evidenceSummary,
          'Evidence stored in incident INC-7.');
      expect(records.single.approvalId, 'resolution-123');
      // The public audit projection intentionally has no path, staging-handle
      // or package-hash fields.
    });

    test('rejects unbounded or invalid query parameters', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      await expectLater(
        journal.queryAudit(const PluginInstallAuditQuery(limit: 501)),
        throwsArgumentError,
      );
      await expectLater(
        journal.queryAudit(const PluginInstallAuditQuery(offset: -1)),
        throwsArgumentError,
      );
      await expectLater(
        journal.queryAudit(const PluginInstallAuditQuery(offset: 100001)),
        throwsArgumentError,
      );
      await expectLater(
        journal.queryAudit(PluginInstallAuditQuery(
          from: DateTime.utc(2026, 11, 28, 12),
          to: DateTime.utc(2026, 11, 28, 11),
        )),
        throwsArgumentError,
      );
    });
  });
}

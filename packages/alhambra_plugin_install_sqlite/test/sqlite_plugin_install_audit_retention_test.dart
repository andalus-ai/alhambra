import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:test/test.dart';

final class _TestArchiveStore implements PluginInstallAuditArchiveStore {
  bool verificationResult = true;
  PluginInstallAuditArchiveBatch? archivedBatch;
  PluginInstallAuditArchiveReceipt? issuedReceipt;

  @override
  Future<PluginInstallAuditArchiveReceipt> archiveAndVerify(
    PluginInstallAuditArchiveBatch batch,
  ) async {
    archivedBatch = batch;
    final receipt = PluginInstallAuditArchiveReceipt(
      archiveId: 'archive-${batch.batchId}',
      batchId: batch.batchId,
      digest: 'sha256:test-integrity-digest',
      recordCount: batch.records.length,
      eventIds: batch.records.map((record) => record.eventId).toList(),
      cutoff: batch.cutoff,
      archivedAt: batch.createdAt,
    );
    issuedReceipt = receipt;
    return receipt;
  }

  @override
  Future<bool> verify(PluginInstallAuditArchiveReceipt receipt) async =>
      verificationResult && receipt.digest == 'sha256:test-integrity-digest';
}

void main() {
  group('SQLite plugin installation audit retention', () {
    test('retention policy is opt-in and validates duration and batch size',
        () {
      final disabled = PluginInstallAuditRetentionPolicy(
        retentionPeriod: const Duration(days: 90),
      );
      expect(disabled.cutoffAt(DateTime.utc(2026, 11, 28)), isNull);

      final enabled = PluginInstallAuditRetentionPolicy(
        retentionPeriod: const Duration(days: 90),
        batchSize: 250,
        enabled: true,
      );
      expect(
        enabled.cutoffAt(DateTime.utc(2026, 11, 28)),
        DateTime.utc(2026, 8, 30),
      );
      expect(
        () => PluginInstallAuditRetentionPolicy(
          retentionPeriod: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => PluginInstallAuditRetentionPolicy(
          retentionPeriod: const Duration(days: 30),
          batchSize: 501,
        ),
        throwsArgumentError,
      );
    });

    test('archives and prunes only verified events from terminal operations',
        () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final archive = _TestArchiveStore();
      final before = DateTime.utc(2026, 11, 1);
      final terminalAt = DateTime.utc(2026, 10, 1);

      await journal.write(PluginInstallJournalEntry(
        operationId: 'terminal-op',
        pluginId: 'example.editor',
        version: '1.0.0',
        status: PluginInstallJournalStatus.verificationStarted,
        updatedAt: terminalAt,
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'terminal-op',
        pluginId: 'example.editor',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: terminalAt.add(const Duration(minutes: 1)),
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'unresolved-op',
        pluginId: 'example.pending',
        version: '2.0.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: terminalAt,
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'active-op',
        pluginId: 'example.active',
        version: '3.0.0',
        status: PluginInstallJournalStatus.extracting,
        updatedAt: terminalAt,
      ));

      final preview = await journal.previewPrunableAudit(before: before);
      expect(preview, hasLength(2));
      expect(preview.map((event) => event.operationId).toSet(),
          {'terminal-op'});
      expect(preview.map((event) => event.eventId).toSet().length, 2);

      final batch = PluginInstallAuditArchiveBatch(
        batchId: 'batch-001',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: before,
        records: preview,
      );
      final receipt = await archive.archiveAndVerify(batch);
      final removed = await journal.pruneArchivedAudit(
        receipt: receipt,
        archiveStore: archive,
      );

      expect(removed, 2);
      expect(await journal.queryAudit(const PluginInstallAuditQuery()), isEmpty);
      expect(await journal.history('terminal-op'), isEmpty);
      expect((await journal.read('terminal-op'))?.status,
          PluginInstallJournalStatus.committed);
      final unresolved = await journal.unresolved();
      expect(unresolved, hasLength(2));
      expect(unresolved.map((entry) => entry.operationId).toSet(),
          {'unresolved-op', 'active-op'});
      expect(await journal.previewPrunableAudit(before: before), isEmpty);
    });

    test('archives manual evidence with its terminal journal events', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final archive = _TestArchiveStore();
      final startedAt = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'manual-op',
        pluginId: 'example.manual',
        version: '1.0.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: startedAt,
      ));
      await journal.reconcileManually(
        operationId: 'manual-op',
        expectedUpdatedAt: startedAt,
        resolution: PluginInstallManualResolution.absentAndClean,
        resolutionId: 'manual-resolution',
        operatorId: 'operator-1',
        evidenceSummary: 'Evidence in incident INC-9.',
        resolvedAt: startedAt.add(const Duration(minutes: 1)),
      );
      expect(await journal.manualReconciliations('manual-op'), hasLength(1));

      final cutoff = DateTime.utc(2026, 11, 1);
      final candidates = await journal.previewPrunableAudit(before: cutoff);
      expect(candidates, hasLength(2));
      expect(candidates.last.evidenceSummary, 'Evidence in incident INC-9.');
      final receipt = await archive.archiveAndVerify(PluginInstallAuditArchiveBatch(
        batchId: 'manual-batch',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: cutoff,
        records: candidates,
      ));
      expect(await journal.pruneArchivedAudit(
        receipt: receipt,
        archiveStore: archive,
      ), 2);
      expect(await journal.manualReconciliations('manual-op'), isEmpty);
      expect((await journal.read('manual-op'))?.status,
          PluginInstallJournalStatus.manuallyReconciled);
    });

    test('does not prune when archive verification fails', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final archive = _TestArchiveStore()..verificationResult = false;
      final time = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op',
        pluginId: 'example.plugin',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: time,
      ));
      final records = await journal.previewPrunableAudit(
        before: DateTime.utc(2026, 11, 1),
      );
      final receipt = await archive.archiveAndVerify(PluginInstallAuditArchiveBatch(
        batchId: 'batch-fail',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: DateTime.utc(2026, 11, 1),
        records: records,
      ));

      await expectLater(
        journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive),
        throwsStateError,
      );
      expect(await journal.queryAudit(const PluginInstallAuditQuery()),
          hasLength(1));
    });

    test('rejects receipt containing an unresolved operation event', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final archive = _TestArchiveStore();
      final time = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'pending-op',
        pluginId: 'example.pending',
        version: '1.0.0',
        status: PluginInstallJournalStatus.needsReconciliation,
        updatedAt: time,
      ));
      final record = (await journal.queryAudit(
        const PluginInstallAuditQuery(),
      )).single;
      final receipt = PluginInstallAuditArchiveReceipt(
        archiveId: 'archive-pending',
        batchId: 'batch-pending',
        digest: 'sha256:test-integrity-digest',
        recordCount: 1,
        eventIds: [record.eventId],
        cutoff: DateTime.utc(2026, 11, 1),
        archivedAt: DateTime.utc(2026, 11, 28),
      );

      await expectLater(
        journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive),
        throwsStateError,
      );
      expect(await journal.queryAudit(const PluginInstallAuditQuery()),
          hasLength(1));
    });

    test('persists archive manifest and replay protection across restart',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-audit-retention-');
      final path = '${directory.path}/install.sqlite';
      var journal = SqlitePluginInstallJournal(path);
      addTearDown(() async {
        journal.close();
        await directory.delete(recursive: true);
      });
      final archive = _TestArchiveStore();
      final eventAt = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'durable-archive-op',
        pluginId: 'example.durable',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: eventAt,
      ));
      final cutoff = DateTime.utc(2026, 11, 1);
      final candidates = await journal.previewPrunableAudit(before: cutoff);
      final receipt = await archive.archiveAndVerify(PluginInstallAuditArchiveBatch(
        batchId: 'durable-batch',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: cutoff,
        records: candidates,
      ));
      await journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive);
      journal.close();

      journal = SqlitePluginInstallJournal(path);
      expect(await journal.queryAudit(const PluginInstallAuditQuery()), isEmpty);
      await expectLater(
        journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive),
        throwsStateError,
      );
      expect((await journal.read('durable-archive-op'))?.status,
          PluginInstallJournalStatus.committed);
    });

    test('rejects replay of an already applied archive receipt', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final archive = _TestArchiveStore();
      final time = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'op-replay',
        pluginId: 'example.plugin',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: time,
      ));
      final records = await journal.previewPrunableAudit(
        before: DateTime.utc(2026, 11, 1),
      );
      final receipt = await archive.archiveAndVerify(PluginInstallAuditArchiveBatch(
        batchId: 'batch-replay',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: DateTime.utc(2026, 11, 1),
        records: records,
      ));
      await journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive);

      await expectLater(
        journal.pruneArchivedAudit(receipt: receipt, archiveStore: archive),
        throwsStateError,
      );
    });
  });
}

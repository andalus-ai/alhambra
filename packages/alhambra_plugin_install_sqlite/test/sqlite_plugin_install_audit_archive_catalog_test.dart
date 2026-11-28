import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:test/test.dart';

final class _Archive implements PluginInstallAuditArchiveStore {
  @override
  Future<PluginInstallAuditArchiveReceipt> archiveAndVerify(
    PluginInstallAuditArchiveBatch batch,
  ) async => PluginInstallAuditArchiveReceipt(
    archiveId: 'archive-${batch.batchId}',
    batchId: batch.batchId,
    digest: 'sha256:catalog-test',
    recordCount: batch.records.length,
    eventIds: batch.records.map((record) => record.eventId).toList(),
    cutoff: batch.cutoff,
    archivedAt: batch.createdAt,
  );

  @override
  Future<bool> verify(PluginInstallAuditArchiveReceipt receipt) async =>
      receipt.digest == 'sha256:catalog-test';
}

void main() {
  group('SQLite installation audit archive catalog', () {
    test('lists manifests and event IDs after pruning, with bounded paging',
        () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final at = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'catalog-op-a',
        pluginId: 'example.catalog.a',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: at,
      ));
      await journal.write(PluginInstallJournalEntry(
        operationId: 'catalog-op-b',
        pluginId: 'example.catalog.b',
        version: '2.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: at.add(const Duration(minutes: 1)),
      ));

      final cutoff = DateTime.utc(2026, 11, 1);
      final archive = _Archive();
      final candidates = await journal.previewPrunableAudit(before: cutoff);
      final batch = PluginInstallAuditArchiveBatch(
        batchId: 'catalog-batch',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: cutoff,
        records: candidates,
      );
      final receipt = await archive.archiveAndVerify(batch);
      await journal.pruneArchivedAudit(
        batch: batch,
        receipt: receipt,
        archiveStore: archive,
      );

      final manifests = await journal.listAuditArchives();
      expect(manifests, hasLength(1));
      expect(manifests.single.archiveId, receipt.archiveId);
      expect(manifests.single.batchId, batch.batchId);
      expect(manifests.single.digest, receipt.digest);
      expect(manifests.single.recordCount, 2);
      expect(await journal.findAuditArchive(receipt.archiveId),
          manifests.single);
      expect(await journal.findAuditArchive('missing'), isNull);
      expect(await journal.archivedEventIds(receipt.archiveId),
          receipt.eventIds..sort());
      expect(await journal.listAuditArchives(limit: 1, offset: 1), isEmpty);
      expect(() => journal.listAuditArchives(limit: 501),
          throwsArgumentError);
      expect(() => journal.listAuditArchives(offset: 100001),
          throwsArgumentError);
      expect(() => journal.archivedEventIds(receipt.archiveId, limit: 0),
          throwsArgumentError);
    });

    test('archive catalog survives reopening the SQLite journal', () async {
      final path = '${DateTime.now().microsecondsSinceEpoch}-archive-catalog.sqlite';
      final journal = SqlitePluginInstallJournal(path);
      addTearDown(() {
        journal.close();
      });
      final at = DateTime.utc(2026, 10, 1);
      await journal.write(PluginInstallJournalEntry(
        operationId: 'catalog-durable-op',
        pluginId: 'example.catalog.durable',
        version: '1.0.0',
        status: PluginInstallJournalStatus.committed,
        updatedAt: at,
      ));
      final cutoff = DateTime.utc(2026, 11, 1);
      final archive = _Archive();
      final records = await journal.previewPrunableAudit(before: cutoff);
      final batch = PluginInstallAuditArchiveBatch(
        batchId: 'catalog-durable-batch',
        createdAt: DateTime.utc(2026, 11, 28),
        cutoff: cutoff,
        records: records,
      );
      final receipt = await archive.archiveAndVerify(batch);
      await journal.pruneArchivedAudit(
        batch: batch,
        receipt: receipt,
        archiveStore: archive,
      );
      journal.close();

      final reopened = SqlitePluginInstallJournal(path);
      addTearDown(reopened.close);
      expect(await reopened.findAuditArchive(receipt.archiveId), isNotNull);
      expect(await reopened.archivedEventIds(receipt.archiveId),
          receipt.eventIds);
    });
  });
}

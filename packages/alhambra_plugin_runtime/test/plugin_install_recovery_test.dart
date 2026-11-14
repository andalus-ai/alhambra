import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const _hash =
    'sha256:0000000000000000000000000000000000000000000000000000000000000000';

class _Journal implements PluginInstallRecoveryJournal {
  final Map<String, PluginInstallJournalEntry> entries = {};

  @override
  Future<void> write(PluginInstallJournalEntry entry) async {
    entries[entry.operationId] = entry;
  }

  @override
  Future<List<PluginInstallJournalEntry>> unresolved() async => entries.values
      .where((entry) => !{
            PluginInstallJournalStatus.committed,
            PluginInstallJournalStatus.rolledBack,
            PluginInstallJournalStatus.failed,
          }.contains(entry.status))
      .toList(growable: false);

  @override
  Future<bool> compareAndSet({
    required String operationId,
    required PluginInstallJournalStatus expectedStatus,
    required DateTime expectedUpdatedAt,
    required PluginInstallJournalEntry replacement,
  }) async {
    final current = entries[operationId];
    if (current == null ||
        current.status != expectedStatus ||
        current.updatedAt != expectedUpdatedAt) return false;
    entries[operationId] = replacement;
    return true;
  }
}

class _FileSystem implements PluginInstallFileSystem {
  bool stagingExists = false;
  bool destinationExists = false;
  bool destinationOwned = false;
  bool rollbackAvailable = false;
  final List<String> calls = [];

  @override
  Future<PluginInstallStaging> createStaging({
    required String operationId,
    required String pluginId,
    required String version,
  }) async => PluginInstallStaging(
        operationId: operationId,
        pluginId: pluginId,
        opaqueHandle: 'stage-$operationId',
      );

  @override
  Future<void> createDirectory(
    PluginInstallStaging staging,
    String relativePath,
  ) async {}

  @override
  Future<void> writeFile({
    required PluginInstallStaging staging,
    required String relativePath,
    required Stream<List<int>> bytes,
    required int maxBytes,
  }) async {}

  @override
  Future<String> destinationPathFor({
    required String pluginId,
    required String version,
  }) async => '/plugins/$pluginId/$version';

  @override
  Future<void> promote(
    PluginInstallStaging staging, {
    required String destinationPath,
  }) async {}

  @override
  Future<void> rollbackPromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  }) async {
    calls.add('rollback');
    destinationExists = false;
    destinationOwned = false;
    rollbackAvailable = false;
  }

  @override
  Future<void> finalizePromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  }) async {
    calls.add('finalize');
    rollbackAvailable = false;
    stagingExists = false;
  }

  @override
  Future<void> discardStaging(PluginInstallStaging staging) async {
    calls.add('discard');
    stagingExists = false;
  }

  @override
  Future<PluginInstallRecoverySnapshot> inspectOperation({
    required String operationId,
    required String pluginId,
    required String? stagingHandle,
    required String? destinationPath,
  }) async {
    calls.add('inspect');
    return PluginInstallRecoverySnapshot(
      stagingExists: stagingExists,
      destinationExists: destinationExists,
      destinationOwnedByOperation: destinationOwned,
      rollbackAvailable: rollbackAvailable,
    );
  }
}

PluginInstallJournalEntry _entry({
  PluginInstallJournalStatus status = PluginInstallJournalStatus.extracting,
  String? stagingHandle = 'stage-op-1',
  String? promotedPath = '/plugins/editor/1.0.0',
}) =>
    PluginInstallJournalEntry(
      operationId: 'op-1',
      pluginId: 'org.example.editor',
      version: '1.0.0',
      status: status,
      updatedAt: DateTime.utc(2026, 1, 1),
      stagingHandle: stagingHandle,
      promotedPath: promotedPath,
      contentHash: _hash,
    );

InstalledPluginRecord _record() => InstalledPluginRecord(
      id: 'org.example.editor',
      version: const SemanticVersion(1, 0, 0),
      contentHash: _hash,
      installedAt: DateTime.utc(2026, 1, 1),
      installPath: '/plugins/editor/1.0.0',
    );

void main() {
  group('PluginInstallRecoveryPlanner', () {
    test('plans staging discard without performing side effects', () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()..stagingExists = true;
      final store = InMemoryInstalledPluginStore();

      final report = await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).inspect();

      expect(report.findings.single.action,
          PluginInstallRecoveryAction.discardStaging);
      expect(report.findings.single.isAutomaticallyExecutable, isFalse);
      expect(fs.calls, ['inspect']);
      expect(journal.entries['op-1']!.status,
          PluginInstallJournalStatus.extracting);
    });

    test('requires manual review when destination ownership is unknown', () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()
        ..destinationExists = true
        ..destinationOwned = false
        ..rollbackAvailable = true;

      final report = await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: InMemoryInstalledPluginStore(),
      ).inspect();

      expect(report.findings.single.action,
          PluginInstallRecoveryAction.manualReview);
    });

    test('plans finalize only when installed record and owned destination agree',
        () async {
      final journal = _Journal()
        ..entries['op-1'] = _entry(
          status: PluginInstallJournalStatus.installedRecordSaved,
        );
      final fs = _FileSystem()
        ..destinationExists = true
        ..destinationOwned = true
        ..rollbackAvailable = true;
      final store = InMemoryInstalledPluginStore();
      await store.save(_record());

      final report = await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).inspect();

      expect(report.findings.single.action,
          PluginInstallRecoveryAction.finalizePromotion);
      expect(report.findings.single.installedRecordMatches, isTrue);
    });
  });

  group('PluginInstallRecoveryExecutor', () {
    test('executes approved discard and persists operator audit metadata',
        () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()..stagingExists = true;
      final store = InMemoryInstalledPluginStore();
      final planner = PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      );
      final finding = (await planner.inspect()).findings.single;

      final result = await PluginInstallRecoveryExecutor(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).execute(
        finding,
        approvedBy: 'operator@example.test',
        approvalId: 'approval-123',
      );

      expect(result.status, PluginInstallJournalStatus.rolledBack);
      expect(result.approvedBy, 'operator@example.test');
      expect(result.approvalId, 'approval-123');
      expect(fs.calls, ['inspect', 'inspect', 'discard']);
    });

    test('rejects stale filesystem evidence before claiming or mutating',
        () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()..stagingExists = true;
      final store = InMemoryInstalledPluginStore();
      final finding = (await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).inspect()).findings.single;
      fs.stagingExists = false;

      await expectLater(
        PluginInstallRecoveryExecutor(
          journal: journal,
          fileSystem: fs,
          installedStore: store,
        ).execute(
          finding,
          approvedBy: 'operator',
          approvalId: 'approval-456',
        ),
        throwsA(isA<PluginInstallRecoveryException>()),
      );

      expect(journal.entries['op-1']!.status,
          PluginInstallJournalStatus.extracting);
      expect(fs.calls, ['inspect', 'inspect']);
      expect(fs.calls, isNot(contains('discard')));
    });


    test('rejects a caller-forged action that differs from fresh planning', () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()..stagingExists = true;
      final store = InMemoryInstalledPluginStore();
      final finding = (await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).inspect()).findings.single;
      final forged = PluginInstallRecoveryFinding(
        journalEntry: finding.journalEntry,
        filesystem: finding.filesystem,
        installedRecordExists: finding.installedRecordExists,
        installedRecordMatches: finding.installedRecordMatches,
        action: PluginInstallRecoveryAction.finalizePromotion,
        guidance: 'forged',
      );

      await expectLater(
        PluginInstallRecoveryExecutor(
          journal: journal,
          fileSystem: fs,
          installedStore: store,
        ).execute(
          forged,
          approvedBy: 'operator',
          approvalId: 'approval-forged',
        ),
        throwsA(isA<PluginInstallRecoveryException>()),
      );
      expect(journal.entries['op-1']!.status,
          PluginInstallJournalStatus.extracting);
      expect(fs.calls, ['inspect', 'inspect']);
    });

    test('finalizes only after explicit approval when record matches',
        () async {
      final journal = _Journal()
        ..entries['op-1'] = _entry(
          status: PluginInstallJournalStatus.installedRecordSaved,
        );
      final fs = _FileSystem()
        ..destinationExists = true
        ..destinationOwned = true
        ..rollbackAvailable = true;
      final store = InMemoryInstalledPluginStore();
      await store.save(_record());
      final finding = (await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).inspect()).findings.single;

      final result = await PluginInstallRecoveryExecutor(
        journal: journal,
        fileSystem: fs,
        installedStore: store,
      ).execute(
        finding,
        approvedBy: 'operator',
        approvalId: 'approval-789',
      );

      expect(result.status, PluginInstallJournalStatus.committed);
      expect(fs.calls, ['inspect', 'inspect', 'finalize']);
    });

    test('does not execute a manual-review finding', () async {
      final journal = _Journal()..entries['op-1'] = _entry();
      final fs = _FileSystem()
        ..destinationExists = true
        ..destinationOwned = false
        ..rollbackAvailable = true;
      final finding = (await PluginInstallRecoveryPlanner(
        journal: journal,
        fileSystem: fs,
        installedStore: InMemoryInstalledPluginStore(),
      ).inspect()).findings.single;

      await expectLater(
        PluginInstallRecoveryExecutor(
          journal: journal,
          fileSystem: fs,
          installedStore: InMemoryInstalledPluginStore(),
        ).execute(
          finding,
          approvedBy: 'operator',
          approvalId: 'approval-manual',
        ),
        throwsA(isA<PluginInstallRecoveryException>()),
      );
      expect(fs.calls, ['inspect']);
    });
  });
}

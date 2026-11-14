import 'dart:io';

import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';

PluginInstallJournalEntry _entry({
  String operationId = 'install-1',
  String pluginId = 'example.plugin',
  String version = '1.0.0',
  PluginInstallJournalStatus status = PluginInstallJournalStatus.verificationStarted,
  DateTime? at,
  String? approvedBy,
  String? approvalId,
}) => PluginInstallJournalEntry(
  operationId: operationId,
  pluginId: pluginId,
  version: version,
  status: status,
  updatedAt: at ?? DateTime.utc(2026, 1, 1),
  contentHash: 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  approvedBy: approvedBy,
  approvalId: approvalId,
);

void main() {
  group('SqlitePluginInstallJournal', () {
    test('persists current state and ordered history across reopen', () async {
      final directory = await Directory.systemTemp.createTemp('alhambra-install-journal-');
      final path = '${directory.path}/install.sqlite';
      final first = SqlitePluginInstallJournal(path);
      await first.write(_entry());
      await first.write(_entry(
        status: PluginInstallJournalStatus.verified,
        at: DateTime.utc(2026, 1, 1, 0, 1),
      ));
      await first.write(_entry(
        status: PluginInstallJournalStatus.recoveryStarted,
        at: DateTime.utc(2026, 1, 1, 0, 2),
        approvedBy: 'operator-1',
        approvalId: 'approval-1',
      ));
      first.close();

      final reopened = SqlitePluginInstallJournal(path);
      addTearDown(() async {
        reopened.close();
        await directory.delete(recursive: true);
      });
      final unresolved = await reopened.unresolved();
      expect(unresolved, hasLength(1));
      expect(unresolved.single.status, PluginInstallJournalStatus.recoveryStarted);
      expect(unresolved.single.approvalId, 'approval-1');
      final history = await reopened.history('install-1');
      expect(history.map((e) => e.status), [
        PluginInstallJournalStatus.verificationStarted,
        PluginInstallJournalStatus.verified,
        PluginInstallJournalStatus.recoveryStarted,
      ]);
    });

    test('CAS permits one competing recovery claim across connections', () async {
      final directory = await Directory.systemTemp.createTemp('alhambra-install-cas-');
      final path = '${directory.path}/install.sqlite';
      final first = SqlitePluginInstallJournal(path);
      final second = SqlitePluginInstallJournal(path);
      addTearDown(() async {
        first.close();
        second.close();
        await directory.delete(recursive: true);
      });
      final initialAt = DateTime.utc(2026, 1, 1);
      await first.write(_entry(at: initialAt));
      final results = await Future.wait([
        first.compareAndSet(
          operationId: 'install-1',
          expectedStatus: PluginInstallJournalStatus.verificationStarted,
          expectedUpdatedAt: initialAt,
          replacement: _entry(
            status: PluginInstallJournalStatus.recoveryStarted,
            at: initialAt.add(const Duration(seconds: 1)),
            approvedBy: 'operator-a',
            approvalId: 'approval-a',
          ),
        ),
        second.compareAndSet(
          operationId: 'install-1',
          expectedStatus: PluginInstallJournalStatus.verificationStarted,
          expectedUpdatedAt: initialAt,
          replacement: _entry(
            status: PluginInstallJournalStatus.recoveryStarted,
            at: initialAt.add(const Duration(seconds: 2)),
            approvedBy: 'operator-b',
            approvalId: 'approval-b',
          ),
        ),
      ]);
      expect(results.where((won) => won), hasLength(1));
      expect(await first.history('install-1'), hasLength(2));
    });

    test('approval identifiers are unique within the database', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      await journal.write(_entry(
        approvedBy: 'operator-a',
        approvalId: 'approval-shared',
      ));
      await expectLater(
        journal.write(_entry(
          operationId: 'install-2',
          approvedBy: 'operator-b',
          approvalId: 'approval-shared',
        )),
        throwsA(anything),
      );
      expect(await journal.unresolved(), hasLength(1));
    });

    test('operation identity cannot be reused for another plugin', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      await journal.write(_entry());
      await expectLater(
        journal.write(_entry(pluginId: 'different.plugin', at: DateTime.utc(2026, 1, 1, 0, 1))),
        throwsStateError,
      );
      expect((await journal.read('install-1'))!.pluginId, 'example.plugin');
    });

    test('terminal operations are excluded from unresolved results', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      await journal.write(_entry(status: PluginInstallJournalStatus.committed));
      expect(await journal.unresolved(), isEmpty);
      await expectLater(
        journal.write(_entry(
          status: PluginInstallJournalStatus.verified,
          at: DateTime.utc(2026, 1, 1, 0, 1),
        )),
        throwsStateError,
      );
    });

    test('CAS rejects stale timestamp and non-advancing replacement time', () async {
      final journal = SqlitePluginInstallJournal.memory();
      addTearDown(journal.close);
      final at = DateTime.utc(2026, 1, 1);
      await journal.write(_entry(at: at));
      expect(await journal.compareAndSet(
        operationId: 'install-1',
        expectedStatus: PluginInstallJournalStatus.verificationStarted,
        expectedUpdatedAt: at.subtract(const Duration(seconds: 1)),
        replacement: _entry(status: PluginInstallJournalStatus.recoveryStarted,
          at: at.add(const Duration(seconds: 1))),
      ), isFalse);
      await expectLater(journal.compareAndSet(
        operationId: 'install-1',
        expectedStatus: PluginInstallJournalStatus.verificationStarted,
        expectedUpdatedAt: at,
        replacement: _entry(status: PluginInstallJournalStatus.recoveryStarted, at: at),
      ), throwsArgumentError);
    });
  });
}

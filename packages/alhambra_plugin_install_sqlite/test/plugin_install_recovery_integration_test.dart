import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_filesystem/alhambra_plugin_install_filesystem.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';

final class _EmptyInstalledPluginStore implements InstalledPluginStore {
  @override
  Future<List<InstalledPluginRecord>> all() async => const [];

  @override
  Future<InstalledPluginRecord?> find(String pluginId) async => null;

  @override
  Future<void> remove(String pluginId) async {}

  @override
  Future<void> save(InstalledPluginRecord plugin) async {
    throw StateError('This recovery scenario must not write installed records.');
  }
}

void main() {
  test('recovery takeover rolls back a promoted tree with a newer fencing token',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('alhambra-install-recovery-');
    final installRoot = await Directory('${directory.path}/install').create();
    final databasePath = '${directory.path}/install.sqlite';
    final journal = SqlitePluginInstallJournal(databasePath);
    final leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    final fileSystem = LocalPluginInstallFileSystem(rootDirectory: installRoot);
    final installedStore = _EmptyInstalledPluginStore();

    addTearDown(() async {
      journal.close();
      leases.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final startedAt = DateTime.utc(2026, 11, 16, 1);
    final operationId = 'install-recovery-takeover';
    const pluginId = 'example.recovery';
    const version = '1.2.3';
    const contentHash =
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    final originalLease = await leases.acquire(
      operationId: operationId,
      ownerId: 'installer-worker',
      now: startedAt,
      leaseDuration: const Duration(seconds: 1),
    );
    expect(originalLease, isNotNull);
    expect(originalLease!.fencingToken, 1);

    expect(
      await journal.advanceFence(
        operationId: operationId,
        fencingToken: originalLease.fencingToken,
      ),
      isTrue,
    );
    expect(
      await fileSystem.advanceFence(
        operationId: operationId,
        fencingToken: originalLease.fencingToken,
      ),
      isTrue,
    );

    final staging = await fileSystem.createStaging(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      fencingToken: originalLease.fencingToken,
    );
    await fileSystem.writeFile(
      staging: staging,
      relativePath: 'README.md',
      bytes: Stream<List<int>>.value([65, 66, 67]),
      maxBytes: 16,
    );
    final destination = await fileSystem.destinationPathFor(
      pluginId: pluginId,
      version: version,
    );
    await fileSystem.promote(staging, destinationPath: destination);

    await journal.write(PluginInstallJournalEntry(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      status: PluginInstallJournalStatus.promoting,
      updatedAt: startedAt.add(const Duration(milliseconds: 500)),
      stagingHandle: staging.opaqueHandle,
      promotedPath: destination,
      contentHash: contentHash,
      fencingToken: originalLease.fencingToken,
    ));

    final takeoverAt = startedAt.add(const Duration(seconds: 2));
    final recoveryLease = await leases.acquire(
      operationId: operationId,
      ownerId: 'recovery-worker',
      now: takeoverAt,
      leaseDuration: const Duration(seconds: 30),
    );
    expect(recoveryLease, isNotNull);
    expect(recoveryLease!.fencingToken, 2);

    expect(
      await journal.advanceFence(
        operationId: operationId,
        fencingToken: recoveryLease.fencingToken,
      ),
      isTrue,
    );
    expect(
      await fileSystem.advanceFence(
        operationId: operationId,
        fencingToken: recoveryLease.fencingToken,
      ),
      isTrue,
    );

    final planner = PluginInstallRecoveryPlanner(
      journal: journal,
      fileSystem: fileSystem,
      installedStore: installedStore,
      clock: () => takeoverAt,
    );
    final report = await planner.inspect();
    expect(report.findings, hasLength(1));
    final finding = report.findings.single;
    expect(finding.action, PluginInstallRecoveryAction.rollbackPromotion);
    expect(finding.filesystem.destinationOwnedByOperation, isTrue);

    final executor = PluginInstallRecoveryExecutor(
      journal: journal,
      fileSystem: fileSystem,
      installedStore: installedStore,
      leaseStore: leases,
      workerId: 'recovery-worker',
      clock: () => takeoverAt,
    );
    final completed = await executor.execute(
      finding,
      approvedBy: 'test-operator',
      approvalId: 'approval-recovery-takeover',
    );

    expect(completed.status, PluginInstallJournalStatus.rolledBack);
    expect(await Directory(destination).exists(), isFalse);
    expect(await journal.unresolved(), isEmpty);
  });
}

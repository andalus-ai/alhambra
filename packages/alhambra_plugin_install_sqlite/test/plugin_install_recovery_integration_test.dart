import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_filesystem/alhambra_plugin_install_filesystem.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';


final class _ArchivePackage implements PluginPackageArchive {
  @override
  PluginPackageManifest get manifest => PluginPackageManifest(
        id: PluginId('example.e2e'),
        name: 'End-to-end Example',
        version: const SemanticVersion(1, 0, 0),
        hostApi: HostApiConstraint(min: const SemanticVersion(1, 0, 0)),
      );

  @override
  PluginPackageMetadata get metadata => PluginPackageMetadata(
        packageId: 'example.e2e',
        version: const SemanticVersion(1, 0, 0),
        contentHash:
            'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        formatVersion: 1,
      );

  @override
  PluginPublisher? get publisher => null;

  @override
  PluginPackageSignature? get signature => null;

  @override
  Stream<PluginArchiveEntry> listEntries() async* {
    yield const PluginArchiveEntry(
      path: 'lib/main.dart',
      kind: PluginArchiveEntryKind.file,
      declaredSizeBytes: 3,
    );
  }

  @override
  Stream<List<int>> readPayload(String path) async* {
    yield [1, 2, 3];
  }
}

final class _AcceptingVerifier implements PluginPackageVerifier {
  @override
  Future<PackageVerificationResult> verify(PluginPackage package) async =>
      const PackageVerified(PluginTrustLevel.verified);
}

final class _AcceptingPreflight implements PluginInstallPreflight {
  @override
  Future<void> validate(PluginPackage package) async {}
}

void main() {
  test('recovery takeover rolls back a promoted tree with a newer fencing token',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('alhambra-install-recovery-');
    final installRoot = await Directory('${directory.path}/install').create();
    final databasePath = '${directory.path}/install.sqlite';
    var journal = SqlitePluginInstallJournal(databasePath);
    var leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    var fileSystem = LocalPluginInstallFileSystem(rootDirectory: installRoot);
    final installedStore = SqliteInstalledPluginStore(databasePath);

    addTearDown(() async {
      journal.close();
      leases.close();
      installedStore.close();
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
    expect(
      await installedStore.advanceFence(
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
    expect(
      await installedStore.advanceFence(
        operationId: operationId,
        fencingToken: recoveryLease.fencingToken,
      ),
      isTrue,
    );

    var clockValue = takeoverAt;
    DateTime advancingClock() {
      final current = clockValue;
      clockValue = clockValue.add(const Duration(milliseconds: 1));
      return current;
    }

    final planner = PluginInstallRecoveryPlanner(
      journal: journal,
      fileSystem: fileSystem,
      installedStore: installedStore,
      clock: advancingClock,
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
      clock: advancingClock,
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
  test('recovery finalizes a promoted tree after installed record survived a crash',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('alhambra-install-finalize-');
    final installRoot = await Directory('${directory.path}/install').create();
    final databasePath = '${directory.path}/install.sqlite';
    final journal = SqlitePluginInstallJournal(databasePath);
    final leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    final installedStore = SqliteInstalledPluginStore(databasePath);
    final fileSystem = LocalPluginInstallFileSystem(rootDirectory: installRoot);

    var originalAdaptersClosed = false;
    addTearDown(() async {
      if (!originalAdaptersClosed) {
        journal.close();
        leases.close();
        installedStore.close();
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final startedAt = DateTime.utc(2026, 11, 18, 1);
    const operationId = 'install-finalize-after-crash';
    const pluginId = 'example.finalize';
    const version = '2.0.0';
    const contentHash =
        'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final originalLease = await leases.acquire(
      operationId: operationId,
      ownerId: 'installer-worker',
      now: startedAt,
      leaseDuration: const Duration(seconds: 1),
    );
    expect(originalLease, isNotNull);
    expect(originalLease!.fencingToken, 1);

    expect(await journal.advanceFence(
      operationId: operationId,
      fencingToken: originalLease.fencingToken,
    ), isTrue);
    expect(await fileSystem.advanceFence(
      operationId: operationId,
      fencingToken: originalLease.fencingToken,
    ), isTrue);
    expect(await installedStore.advanceFence(
      operationId: operationId,
      fencingToken: originalLease.fencingToken,
    ), isTrue);

    final staging = await fileSystem.createStaging(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      fencingToken: originalLease.fencingToken,
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
    await fileSystem.promote(staging, destinationPath: destination);

    final installedRecord = InstalledPluginRecord(
      id: pluginId,
      version: SemanticVersion.parse(version),
      contentHash: contentHash,
      installedAt: startedAt,
      installPath: destination,
    );
    expect(await installedStore.createIfAbsentFenced(
      installedRecord,
      operationId: operationId,
      fencingToken: originalLease.fencingToken,
    ), isTrue);

    await journal.write(PluginInstallJournalEntry(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      status: PluginInstallJournalStatus.installedRecordSaved,
      updatedAt: startedAt.add(const Duration(milliseconds: 500)),
      stagingHandle: staging.opaqueHandle,
      promotedPath: destination,
      contentHash: contentHash,
      fencingToken: originalLease.fencingToken,
    ));

    // Simulate process restart: close and reopen every durable adapter.
    journal.close();
    leases.close();
    installedStore.close();
    originalAdaptersClosed = true;
    final reopenedJournal = SqlitePluginInstallJournal(databasePath);
    final reopenedLeases = SqlitePluginInstallOperationLeaseStore(databasePath);
    final reopenedStore = SqliteInstalledPluginStore(databasePath);
    final reopenedFileSystem =
        LocalPluginInstallFileSystem(rootDirectory: installRoot);
    addTearDown(() async {
      reopenedJournal.close();
      reopenedLeases.close();
      reopenedStore.close();
    });

    final takeoverAt = startedAt.add(const Duration(seconds: 2));
    final recoveryLease = await reopenedLeases.acquire(
      operationId: operationId,
      ownerId: 'recovery-worker',
      now: takeoverAt,
      leaseDuration: const Duration(seconds: 30),
    );
    expect(recoveryLease, isNotNull);
    expect(recoveryLease!.fencingToken, 2);
    expect(await reopenedJournal.advanceFence(
      operationId: operationId,
      fencingToken: recoveryLease.fencingToken,
    ), isTrue);
    expect(await reopenedFileSystem.advanceFence(
      operationId: operationId,
      fencingToken: recoveryLease.fencingToken,
    ), isTrue);
    expect(await reopenedStore.advanceFence(
      operationId: operationId,
      fencingToken: recoveryLease.fencingToken,
    ), isTrue);

    var clockValue = takeoverAt;
    DateTime advancingClock() {
      final current = clockValue;
      clockValue = clockValue.add(const Duration(milliseconds: 1));
      return current;
    }

    final report = await PluginInstallRecoveryPlanner(
      journal: reopenedJournal,
      fileSystem: reopenedFileSystem,
      installedStore: reopenedStore,
      clock: advancingClock,
    ).inspect();
    expect(report.findings, hasLength(1));
    final finding = report.findings.single;
    expect(finding.action, PluginInstallRecoveryAction.finalizePromotion);
    expect(finding.installedRecordExists, isTrue);
    expect(finding.installedRecordMatches, isTrue);

    final completed = await PluginInstallRecoveryExecutor(
      journal: reopenedJournal,
      fileSystem: reopenedFileSystem,
      installedStore: reopenedStore,
      leaseStore: reopenedLeases,
      workerId: 'recovery-worker',
      clock: advancingClock,
    ).execute(
      finding,
      approvedBy: 'test-operator',
      approvalId: 'approval-finalize-after-crash',
    );

    expect(completed.status, PluginInstallJournalStatus.committed);
    expect(await reopenedStore.find(pluginId), isNotNull);
    expect(await Directory(destination).exists(), isTrue);
    expect(await reopenedJournal.unresolved(), isEmpty);
  });

  test('transactional installer commits using all durable host adapters',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('alhambra-install-e2e-');
    final installRoot = await Directory('${directory.path}/install').create();
    final databasePath = '${directory.path}/install.sqlite';
    final journal = SqlitePluginInstallJournal(databasePath);
    final leases = SqlitePluginInstallOperationLeaseStore(databasePath);
    final installedStore = SqliteInstalledPluginStore(databasePath);
    final fileSystem = LocalPluginInstallFileSystem(rootDirectory: installRoot);
    addTearDown(() async {
      journal.close();
      leases.close();
      installedStore.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final installer = TransactionalPluginInstaller(
      verifier: _AcceptingVerifier(),
      preflight: _AcceptingPreflight(),
      fileSystem: fileSystem,
      installedStore: installedStore,
      journal: journal,
      leaseStore: leases,
      workerId: 'integration-installer',
      leaseDuration: const Duration(minutes: 1),
      clock: () => DateTime.utc(2026, 11, 19, 1),
      operationIdFactory: () => 'install-e2e-success',
    );

    final result = await installer.install(_ArchivePackage());
    expect(result, isA<PluginInstalled>());
    final installed = await installedStore.find('example.e2e');
    expect(installed, isNotNull);
    expect(installed!.version, const SemanticVersion(1, 0, 0));
    expect(installed.contentHash,
        'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc');
    expect(await Directory(result.installPath).exists(), isTrue);
    expect(await journal.unresolved(), isEmpty);
  });

}

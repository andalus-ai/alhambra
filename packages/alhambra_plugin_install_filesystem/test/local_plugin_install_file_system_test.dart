import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_filesystem/alhambra_plugin_install_filesystem.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late LocalPluginInstallFileSystem fileSystem;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('alhambra-local-install-');
    fileSystem = LocalPluginInstallFileSystem(rootDirectory: temp);
    await fileSystem.initialize();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('fences staging, extraction, promotion and rollback', () async {
    expect(await fileSystem.advanceFence(operationId: 'op-1', fencingToken: 1), isTrue);
    final staging = await fileSystem.createStaging(
      operationId: 'op-1', pluginId: 'demo.plugin', version: '1.0.0', fencingToken: 1,
    );
    await fileSystem.writeFile(
      staging: staging,
      relativePath: 'lib/plugin.dart',
      bytes: Stream.value([1, 2, 3]),
      maxBytes: 10,
    );
    final destination = await fileSystem.destinationPathFor(pluginId: 'demo.plugin', version: '1.0.0');
    await fileSystem.promote(staging, destinationPath: destination);
    final snapshot = await fileSystem.inspectOperation(
      operationId: 'op-1', pluginId: 'demo.plugin', stagingHandle: staging.opaqueHandle,
      destinationPath: destination,
    );
    expect(snapshot.destinationExists, isTrue);
    expect(snapshot.destinationOwnedByOperation, isTrue);
    expect(snapshot.rollbackAvailable, isTrue);
    await fileSystem.rollbackPromotion(staging, promotedPath: destination);
    expect(Directory(destination).existsSync(), isFalse);
  });

  test('finalization retains durable ownership evidence for interrupted journal commit', () async {
    await fileSystem.advanceFence(operationId: 'op-final', fencingToken: 7);
    final staging = await fileSystem.createStaging(
      operationId: 'op-final', pluginId: 'demo.plugin', version: '2.0.0', fencingToken: 7,
    );
    final destination = await fileSystem.destinationPathFor(
      pluginId: 'demo.plugin', version: '2.0.0',
    );
    await fileSystem.promote(staging, destinationPath: destination);
    await fileSystem.finalizePromotion(staging, promotedPath: destination);
    final snapshot = await fileSystem.inspectOperation(
      operationId: 'op-final', pluginId: 'demo.plugin',
      stagingHandle: staging.opaqueHandle, destinationPath: destination,
    );
    expect(snapshot.destinationExists, isTrue);
    expect(snapshot.destinationOwnedByOperation, isTrue);
    expect(snapshot.rollbackAvailable, isFalse);
    await fileSystem.finalizePromotion(staging, promotedPath: destination);
  });

  test('stale worker cannot write after a newer fence is registered', () async {
    await fileSystem.advanceFence(operationId: 'op-2', fencingToken: 1);
    final stale = await fileSystem.createStaging(
      operationId: 'op-2', pluginId: 'demo.plugin', version: '1.0.0', fencingToken: 1,
    );
    expect(await fileSystem.advanceFence(operationId: 'op-2', fencingToken: 2), isTrue);
    await expectLater(
      fileSystem.createDirectory(stale, 'lib'),
      throwsStateError,
    );
    expect(await fileSystem.advanceFence(operationId: 'op-2', fencingToken: 1), isFalse);
  });

  test('promotion never overwrites an existing destination', () async {
    await fileSystem.advanceFence(operationId: 'op-3', fencingToken: 1);
    final staging = await fileSystem.createStaging(
      operationId: 'op-3', pluginId: 'demo.plugin', version: '1.0.0', fencingToken: 1,
    );
    final destination = await fileSystem.destinationPathFor(pluginId: 'demo.plugin', version: '1.0.0');
    await Directory(destination).create(recursive: true);
    await expectLater(fileSystem.promote(staging, destinationPath: destination), throwsStateError);
    expect(await Directory(destination).exists(), isTrue);
  });

  test('rejects path traversal and reserved ownership metadata', () async {
    await fileSystem.advanceFence(operationId: 'op-4', fencingToken: 1);
    final staging = await fileSystem.createStaging(
      operationId: 'op-4', pluginId: 'demo.plugin', version: '1.0.0', fencingToken: 1,
    );
    await expectLater(
      fileSystem.writeFile(
        staging: staging, relativePath: '../escape',
        bytes: Stream.value([1]), maxBytes: 10,
      ),
      throwsArgumentError,
    );
    await expectLater(
      fileSystem.createDirectory(staging, '.alhambra-install-owner.json'),
      throwsArgumentError,
    );
  });

  test('rejects a stale token when attempting rollback or finalization', () async {
    await fileSystem.advanceFence(operationId: 'op-5', fencingToken: 1);
    final staging = await fileSystem.createStaging(
      operationId: 'op-5', pluginId: 'demo.plugin', version: '1.0.0', fencingToken: 1,
    );
    final destination = await fileSystem.destinationPathFor(pluginId: 'demo.plugin', version: '1.0.0');
    await fileSystem.promote(staging, destinationPath: destination);
    await fileSystem.advanceFence(operationId: 'op-5', fencingToken: 2);
    await expectLater(
      fileSystem.rollbackPromotion(staging, promotedPath: destination),
      throwsStateError,
    );
    await expectLater(
      fileSystem.finalizePromotion(staging, promotedPath: destination),
      throwsStateError,
    );
  });
}

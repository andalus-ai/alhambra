import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_install_sqlite/alhambra_plugin_install_sqlite.dart';
import 'package:test/test.dart';

InstalledPluginRecord record({
  String id = 'example.demo',
  String version = '1.2.3',
  String hash = 'sha256:abc123',
  String path = '/plugins/example.demo/1.2.3',
  DateTime? installedAt,
  PluginPublisher? publisher,
}) =>
    InstalledPluginRecord(
      id: id,
      version: SemanticVersion.parse(version),
      contentHash: hash,
      publisher: publisher,
      installedAt: installedAt ?? DateTime.utc(2026, 11, 17, 1),
      installPath: path,
    );

void main() {
  group('SqliteInstalledPluginStore', () {
    test('persists records and publisher metadata across reopen', () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-installed-store-');
      final database = '${directory.path}/installed.sqlite';
      final publisher = PluginPublisher(
        id: 'publisher.example',
        name: 'Example Publisher',
        website: 'https://example.test',
      );
      var store = SqliteInstalledPluginStore(database);
      await store.save(record(publisher: publisher));
      store.close();

      store = SqliteInstalledPluginStore(database);
      addTearDown(() async {
        store.close();
        await directory.delete(recursive: true);
      });

      final restored = await store.find('example.demo');
      expect(restored, isNotNull);
      expect(restored!.version, SemanticVersion.parse('1.2.3'));
      expect(restored.contentHash, 'sha256:abc123');
      expect(restored.publisher?.id, publisher.id);
      expect(restored.publisher?.name, publisher.name);
      expect(restored.publisher?.website, publisher.website);
      expect(restored.installPath, '/plugins/example.demo/1.2.3');
      expect(await store.all(), hasLength(1));
    });

    test('create-only writes and compare-and-remove are atomic and exact', () async {
      final store = SqliteInstalledPluginStore.memory();
      addTearDown(store.close);
      final candidate = record();

      expect(await store.createIfAbsent(candidate), isTrue);
      expect(await store.createIfAbsent(candidate), isFalse);
      expect(
        await store.removeIfMatches(
          record(hash: 'sha256:different'),
        ),
        isFalse,
      );
      expect(await store.find(candidate.id), isNotNull);
      expect(await store.removeIfMatches(candidate), isTrue);
      expect(await store.find(candidate.id), isNull);
    });

    test('fenced create rejects unregistered and stale tokens', () async {
      final store = SqliteInstalledPluginStore.memory();
      addTearDown(store.close);
      final candidate = record();

      await expectLater(
        store.createIfAbsentFenced(
          candidate,
          operationId: 'install-1',
          fencingToken: 1,
        ),
        throwsStateError,
      );
      expect(
        await store.advanceFence(operationId: 'install-1', fencingToken: 1),
        isTrue,
      );
      expect(
        await store.createIfAbsentFenced(
          candidate,
          operationId: 'install-1',
          fencingToken: 1,
        ),
        isTrue,
      );
      expect(
        await store.advanceFence(operationId: 'install-1', fencingToken: 2),
        isTrue,
      );
      await expectLater(
        store.createIfAbsentFenced(
          record(id: 'example.other'),
          operationId: 'install-1',
          fencingToken: 1,
        ),
        throwsStateError,
      );
      expect(
        await store.advanceFence(operationId: 'install-1', fencingToken: 1),
        isFalse,
      );
    });

    test('new recovery token can remove only its own operation record', () async {
      final store = SqliteInstalledPluginStore.memory();
      addTearDown(store.close);
      final candidate = record();

      await store.advanceFence(operationId: 'install-owner', fencingToken: 1);
      expect(
        await store.createIfAbsentFenced(
          candidate,
          operationId: 'install-owner',
          fencingToken: 1,
        ),
        isTrue,
      );

      // Recovery takeover advances mutation authority but preserves operation
      // ownership, allowing compensation for the interrupted installation.
      await store.advanceFence(operationId: 'install-owner', fencingToken: 2);
      await store.advanceFence(operationId: 'different-operation', fencingToken: 1);
      expect(
        await store.removeIfMatchesFenced(
          candidate,
          operationId: 'different-operation',
          fencingToken: 1,
        ),
        isFalse,
      );
      expect(
        await store.removeIfMatchesFenced(
          candidate,
          operationId: 'install-owner',
          fencingToken: 1,
        ),
        throwsStateError,
      );
      expect(
        await store.removeIfMatchesFenced(
          candidate,
          operationId: 'install-owner',
          fencingToken: 2,
        ),
        isTrue,
      );
      expect(await store.find(candidate.id), isNull);
    });

    test('unfenced APIs cannot overwrite or remove operation-owned rows', () async {
      final store = SqliteInstalledPluginStore.memory();
      addTearDown(store.close);
      final candidate = record();
      await store.advanceFence(operationId: 'install-owned', fencingToken: 1);
      await store.createIfAbsentFenced(
        candidate,
        operationId: 'install-owned',
        fencingToken: 1,
      );

      await expectLater(
        store.save(record(version: '9.9.9')),
        throwsStateError,
      );
      await expectLater(store.remove(candidate.id), throwsStateError);
      expect((await store.find(candidate.id))!.version, candidate.version);
    });

    test('different operations cannot remove one another records', () async {
      final store = SqliteInstalledPluginStore.memory();
      addTearDown(store.close);
      final candidate = record();
      await store.advanceFence(operationId: 'install-a', fencingToken: 1);
      await store.advanceFence(operationId: 'install-b', fencingToken: 1);
      await store.createIfAbsentFenced(
        candidate,
        operationId: 'install-a',
        fencingToken: 1,
      );
      expect(
        await store.removeIfMatchesFenced(
          candidate,
          operationId: 'install-b',
          fencingToken: 1,
        ),
        isFalse,
      );
      expect(await store.find(candidate.id), isNotNull);
    });

    test('two connections cannot both create the same plugin record', () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-installed-race-');
      final database = '${directory.path}/installed.sqlite';
      final first = SqliteInstalledPluginStore(database);
      final second = SqliteInstalledPluginStore(database);
      addTearDown(() async {
        first.close();
        second.close();
        await directory.delete(recursive: true);
      });

      final outcomes = await Future.wait([
        first.createIfAbsent(record()),
        second.createIfAbsent(record()),
      ]);
      expect(outcomes.where((created) => created), hasLength(1));
      expect(outcomes.where((created) => !created), hasLength(1));
    });


    test('coexists with journal and lease adapters in one database', () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-installed-shared-db-');
      final database = '${directory.path}/shared.sqlite';
      final journal = SqlitePluginInstallJournal(database);
      final leases = SqlitePluginInstallOperationLeaseStore(database);
      final store = SqliteInstalledPluginStore(database);
      addTearDown(() async {
        store.close();
        leases.close();
        journal.close();
        await directory.delete(recursive: true);
      });

      final lease = await leases.acquire(
        operationId: 'shared-operation',
        ownerId: 'worker',
        now: DateTime.utc(2026, 11, 17),
        leaseDuration: const Duration(minutes: 1),
      );
      expect(lease, isNotNull);
      await journal.advanceFence(
        operationId: 'shared-operation',
        fencingToken: lease!.fencingToken,
      );
      await store.advanceFence(
        operationId: 'shared-operation',
        fencingToken: lease.fencingToken,
      );
      expect(
        await store.createIfAbsentFenced(
          record(),
          operationId: 'shared-operation',
          fencingToken: lease.fencingToken,
        ),
        isTrue,
      );
      expect(await store.find('example.demo'), isNotNull);
    });

    test('fencing tokens survive store reopen', () async {
      final directory =
          await Directory.systemTemp.createTemp('alhambra-installed-fence-');
      final database = '${directory.path}/installed.sqlite';
      var store = SqliteInstalledPluginStore(database);
      await store.advanceFence(operationId: 'durable-operation', fencingToken: 8);
      store.close();

      store = SqliteInstalledPluginStore(database);
      addTearDown(() async {
        store.close();
        await directory.delete(recursive: true);
      });
      expect(
        await store.advanceFence(operationId: 'durable-operation', fencingToken: 7),
        isFalse,
      );
      expect(
        await store.advanceFence(operationId: 'durable-operation', fencingToken: 8),
        isTrue,
      );
      expect(
        await store.advanceFence(operationId: 'durable-operation', fencingToken: 9),
        isTrue,
      );
    });
  });
}

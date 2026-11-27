import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_provenance_sqlite/alhambra_plugin_provenance_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:test/test.dart';

PluginRecoveryProvenanceEvent provenanceEvent({
  required int sequence,
  required String id,
  String? previous,
}) => PluginRecoveryProvenanceEvent(
  eventId: id,
  sequence: sequence,
  action: PluginRecoveryProvenanceAction.exported,
  occurredAt: DateTime.utc(2026, 1, sequence),
  sourceDeploymentId: 'deployment-a',
  actorId: 'operator-a',
  packageId: 'package-a',
  packageDigestAlgorithm: 'test',
  packageDigest: 'package-digest-$sequence',
  previousEventDigest: previous,
  eventDigestAlgorithm: 'test',
  eventDigest: 'digest-$sequence',
);

PluginRecoveryProvenanceAnchor anchor({
  required int sequence,
  required int provenanceSequence,
}) => PluginRecoveryProvenanceAnchor(
  chainId: 'chain-a',
  anchorSequence: sequence,
  provenanceSequence: provenanceSequence,
  headEventDigestAlgorithm: 'test',
  headEventDigest: 'digest-$provenanceSequence',
  anchoredAt: DateTime.utc(2026, 1, sequence),
  signerKeyId: 'key-a',
  signatureAlgorithm: 'test-signature',
  signature: 'signature-$sequence',
);

PluginRecoverySigningKeyLifecycleEvent keyEvent({
  required int sequence,
  required String id,
}) => PluginRecoverySigningKeyLifecycleEvent(
  eventId: id,
  sequence: sequence,
  keyId: 'key-a',
  algorithm: 'Ed25519',
  principalId: 'host-a',
  action: PluginRecoverySigningKeyLifecycleAction.activated,
  occurredAt: DateTime.utc(2026, 1, sequence),
);

void main() {
  group('SQLite provenance persistence', () {
    late Directory directory;
    late String path;
    late List<SqlitePluginRecoveryProvenancePersistence> stores;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('alhambra-provenance-');
      path = '${directory.path}/provenance.sqlite';
      stores = [];
    });

    tearDown(() async {
      for (final store in stores) {
        store.close();
      }
      await directory.delete(recursive: true);
    });

    SqlitePluginRecoveryProvenancePersistence openStore() {
      final store = SqlitePluginRecoveryProvenancePersistence(path);
      stores.add(store);
      return store;
    }

    test('persists all three histories across close and reopen', () async {
      final first = openStore();
      expect(await first.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'event-1'),
      ), isTrue);
      expect(await first.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-a',
        expectedAnchorSequence: 0,
        anchor: anchor(sequence: 1, provenanceSequence: 1),
      ), isTrue);
      expect(await first.keyHistoryStore.appendIfSequenceMatches(
        expectedSequence: 0,
        event: keyEvent(sequence: 1, id: 'key-event-1'),
      ), isTrue);
      first.close();

      final reopened = openStore();
      expect((await reopened.provenanceStore.readAll()).single.eventDigest,
          'digest-1');
      expect((await reopened.anchorStore.readAll('chain-a')).single.signature,
          'signature-1');
      expect((await reopened.keyHistoryStore.readAll()).single.keyId, 'key-a');
    });

    test('serializes competing appenders across independent connections', () async {
      final first = openStore();
      final second = openStore();

      final results = await Future.wait([
        first.provenanceStore.appendIfHeadMatches(
          expectedSequence: 0,
          expectedHeadDigest: null,
          event: provenanceEvent(sequence: 1, id: 'event-a'),
        ),
        second.provenanceStore.appendIfHeadMatches(
          expectedSequence: 0,
          expectedHeadDigest: null,
          event: provenanceEvent(sequence: 1, id: 'event-b'),
        ),
      ]);
      expect(results.where((result) => result).length, 1);
      expect((await first.provenanceStore.readAll()).length, 1);
    });

    test('rejects stale heads and duplicate key-history sequence', () async {
      final store = openStore();
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'event-1'),
      ), isTrue);
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'event-stale'),
      ), isFalse);
      expect(await store.keyHistoryStore.appendIfSequenceMatches(
        expectedSequence: 0,
        event: keyEvent(sequence: 1, id: 'key-event-1'),
      ), isTrue);
      expect(await store.keyHistoryStore.appendIfSequenceMatches(
        expectedSequence: 0,
        event: keyEvent(sequence: 1, id: 'key-event-2'),
      ), isFalse);
    });

    test('rejects duplicate provenance IDs and non-monotonic anchors', () async {
      final store = openStore();
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'event-1'),
      ), isTrue);
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 1,
        expectedHeadDigest: 'digest-1',
        event: provenanceEvent(
          sequence: 2,
          id: 'event-1',
          previous: 'digest-1',
        ),
      ), isFalse);
      expect(await store.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-a',
        expectedAnchorSequence: 0,
        anchor: anchor(sequence: 1, provenanceSequence: 2),
      ), isTrue);
      expect(await store.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-a',
        expectedAnchorSequence: 1,
        anchor: anchor(sequence: 2, provenanceSequence: 1),
      ), isFalse);
      expect((await store.anchorStore.readAll('chain-a')).length, 1);
    });

    test('passes the shared recovery provenance adapter conformance suite', () async {
      final store = openStore();
      const suite = PluginRecoveryProvenanceConformanceSuite();

      final provenance = await suite.verifyProvenanceStore(
        store: store.provenanceStore,
        runId: 'sqlite-provenance',
        fixture: ({
          required String eventId,
          required int sequence,
          required String? previousEventDigest,
        }) => provenanceEvent(
          sequence: sequence,
          id: eventId,
          previous: previousEventDigest,
        ),
      );
      final keyHistory = await suite.verifySigningKeyHistoryStore(
        store: store.keyHistoryStore,
        runId: 'sqlite-key-history',
        fixture: ({
          required String eventId,
          required int sequence,
        }) => keyEvent(sequence: sequence, id: eventId),
      );
      final anchors = await suite.verifyAnchorStore(
        store: store.anchorStore,
        chainId: 'sqlite-conformance-chain',
        runId: 'sqlite-anchor',
      );

      expect(provenance.isConformant, isTrue,
          reason: provenance.checks.map((check) => '${check.name}: ${check.detail}').join('\n'));
      expect(keyHistory.isConformant, isTrue,
          reason: keyHistory.checks.map((check) => '${check.name}: ${check.detail}').join('\n'));
      expect(anchors.isConformant, isTrue,
          reason: anchors.checks.map((check) => '${check.name}: ${check.detail}').join('\n'));
    });

    test('reports database configuration, counts, and quick-check health', () async {
      final store = openStore();
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'health-event'),
      ), isTrue);
      final health = store.inspect();

      expect(health.schemaVersion, 1);
      expect(health.journalMode.toLowerCase(), 'wal');
      expect(health.synchronousMode, 2);
      expect(health.busyTimeoutMilliseconds, 5000);
      expect(health.provenanceEventCount, 1);
      expect(health.anchorCount, 0);
      expect(health.signingKeyEventCount, 0);
      expect(health.quickCheckResult, 'ok');
      expect(health.quickCheckPassed, isTrue);
    });

    test('supports explicit WAL checkpoint and reports its result', () async {
      final store = openStore();
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'checkpoint-event'),
      ), isTrue);

      final checkpoint = store.checkpointWal();
      expect(checkpoint.busy, 0);
      expect(
        checkpoint.checkpointedFrames,
        lessThanOrEqualTo(checkpoint.logFrames),
      );
    });

    test('rejects WAL checkpoint for in-memory databases', () {
      final store = SqlitePluginRecoveryProvenancePersistence.memory();
      addTearDown(store.close);
      expect(
        () => store.checkpointWal(),
        throwsStateError,
      );
    });


    test('serializes competing appenders from independent OS processes', () async {
      final fixture = 'test/fixtures/sqlite_provenance_writer.dart';
      final processes = await Future.wait([
        Process.run(
          Platform.resolvedExecutable,
          ['run', fixture, path, 'process-event-a'],
          workingDirectory: Directory.current.path,
        ),
        Process.run(
          Platform.resolvedExecutable,
          ['run', fixture, path, 'process-event-b'],
          workingDirectory: Directory.current.path,
        ),
      ]);

      for (final process in processes) {
        expect(
          process.exitCode,
          0,
          reason: 'stdout: ${process.stdout}\\nstderr: ${process.stderr}',
        );
      }
      final results = processes
          .map((process) =>
              jsonDecode(process.stdout.toString().trim()) as Map<String, dynamic>)
          .toList(growable: false);
      expect(results.where((result) => result['appended'] == true).length, 1);
      expect(results.where((result) => result['appended'] == false).length, 1);

      final store = openStore();
      expect((await store.provenanceStore.readAll()).length, 1);
    });

    test('creates a consistent standalone backup and restores all histories', () async {
      final store = openStore();
      expect(await store.provenanceStore.appendIfHeadMatches(
        expectedSequence: 0,
        expectedHeadDigest: null,
        event: provenanceEvent(sequence: 1, id: 'backup-event'),
      ), isTrue);
      expect(await store.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-a',
        expectedAnchorSequence: 0,
        anchor: anchor(sequence: 1, provenanceSequence: 1),
      ), isTrue);
      expect(await store.keyHistoryStore.appendIfSequenceMatches(
        expectedSequence: 0,
        event: keyEvent(sequence: 1, id: 'backup-key-event'),
      ), isTrue);

      final backupPath = '${directory.path}/provenance-backup.sqlite';
      store.backupTo(backupPath);
      final restored = SqlitePluginRecoveryProvenancePersistence(backupPath);
      addTearDown(restored.close);

      expect((await restored.provenanceStore.readAll()).single.eventId,
          'backup-event');
      expect((await restored.anchorStore.readAll('chain-a')).single.signature,
          'signature-1');
      expect((await restored.keyHistoryStore.readAll()).single.eventId,
          'backup-key-event');
      expect(restored.inspect().quickCheckPassed, isTrue);
    });

    test('rejects an empty SQLite backup destination', () {
      final store = openStore();
      expect(() => store.backupTo('  '), throwsArgumentError);
    });

    test('isolates anchor sequence per chain', () async {
      final store = openStore();
      final chainB = PluginRecoveryProvenanceAnchor(
        chainId: 'chain-b',
        anchorSequence: 1,
        provenanceSequence: 1,
        headEventDigestAlgorithm: 'test',
        headEventDigest: 'digest-b',
        anchoredAt: DateTime.utc(2026, 1),
        signerKeyId: 'key-b',
        signatureAlgorithm: 'test-signature',
        signature: 'signature-b',
      );
      expect(await store.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-a',
        expectedAnchorSequence: 0,
        anchor: anchor(sequence: 1, provenanceSequence: 1),
      ), isTrue);
      expect(await store.anchorStore.appendIfSequenceMatches(
        chainId: 'chain-b',
        expectedAnchorSequence: 0,
        anchor: chainB,
      ), isTrue);
      expect((await store.anchorStore.readAll('chain-a')).single.chainId,
          'chain-a');
      expect((await store.anchorStore.readAll('chain-b')).single.chainId,
          'chain-b');
    });
  });
}

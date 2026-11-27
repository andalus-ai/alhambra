import 'dart:io';

import 'package:alhambra_plugin_provenance_sqlite/alhambra_plugin_provenance_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
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

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('alhambra-provenance-');
      path = '${directory.path}/provenance.sqlite';
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('persists all three histories across close and reopen', () async {
      final first = SqlitePluginRecoveryProvenancePersistence(path);
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

      final reopened = SqlitePluginRecoveryProvenancePersistence(path);
      addTearDown(reopened.close);
      expect((await reopened.provenanceStore.readAll()).single.eventDigest,
          'digest-1');
      expect((await reopened.anchorStore.readAll('chain-a')).single.signature,
          'signature-1');
      expect((await reopened.keyHistoryStore.readAll()).single.keyId, 'key-a');
    });

    test('serializes competing appenders across independent connections', () async {
      final first = SqlitePluginRecoveryProvenancePersistence(path);
      final second = SqlitePluginRecoveryProvenancePersistence(path);
      addTearDown(first.close);
      addTearDown(second.close);

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
      final store = SqlitePluginRecoveryProvenancePersistence(path);
      addTearDown(store.close);
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

    test('isolates anchor sequence per chain', () async {
      final store = SqlitePluginRecoveryProvenancePersistence(path);
      addTearDown(store.close);
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

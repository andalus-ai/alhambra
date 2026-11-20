import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Signer implements PluginRecoveryArchivePackageSigner {
  @override
  Future<String> sign({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
  }) async => '$algorithm|$keyId|$canonicalPayload';
}

final class _SignatureVerifier
    implements PluginRecoveryArchivePackageSignatureVerifier {
  @override
  Future<bool> verify({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
    required String signature,
  }) async => signature == '$algorithm|$keyId|$canonicalPayload';
}

PluginRecoveryProvenanceEvent _provenanceFixture({
  required String eventId,
  required int sequence,
  required String? previousEventDigest,
}) => PluginRecoveryProvenanceEvent(
  eventId: eventId,
  sequence: sequence,
  action: PluginRecoveryProvenanceAction.exported,
  occurredAt: DateTime.utc(2026, 1, 1, 0, sequence),
  sourceDeploymentId: 'deployment-a',
  packageId: 'package-a',
  packageDigestAlgorithm: 'sha256',
  packageDigest: 'package-digest',
  previousEventDigest: previousEventDigest,
  eventDigestAlgorithm: 'test-digest',
  eventDigest: 'event-digest-$eventId',
);

PluginRecoverySigningKeyLifecycleEvent _keyFixture({
  required String eventId,
  required int sequence,
}) => PluginRecoverySigningKeyLifecycleEvent(
  eventId: eventId,
  sequence: sequence,
  keyId: 'key-$eventId',
  algorithm: 'ed25519',
  principalId: 'publisher-a',
  action: PluginRecoverySigningKeyLifecycleAction.activated,
  occurredAt: DateTime.utc(2026, 1, 1, 0, sequence),
);

void main() {
  group('PluginRecoveryProvenanceConformanceSuite', () {
    test('checks provenance, key history, and anchor stores', () async {
      const suite = PluginRecoveryProvenanceConformanceSuite();
      final provenance = await suite.verifyProvenanceStore(
        store: InMemoryPluginRecoveryProvenanceStore(),
        fixture: _provenanceFixture,
        runId: 'adapter-one',
      );
      final keys = await suite.verifySigningKeyHistoryStore(
        store: InMemoryPluginRecoverySigningKeyHistoryStore(),
        fixture: _keyFixture,
        runId: 'adapter-two',
      );
      final anchors = await suite.verifyAnchorStore(
        store: InMemoryPluginRecoveryProvenanceAnchorStore(),
        chainId: 'chain-a',
        runId: 'adapter-three',
      );

      expect(provenance.isConformant, isTrue);
      expect(provenance.passedCount, 5);
      expect(keys.isConformant, isTrue);
      expect(keys.passedCount, 4);
      expect(anchors.isConformant, isTrue);
      expect(anchors.passedCount, 3);
    });

    test('rejects unsafe run identifiers and empty chain identifiers', () async {
      const suite = PluginRecoveryProvenanceConformanceSuite();
      await expectLater(
        suite.verifyProvenanceStore(
          store: InMemoryPluginRecoveryProvenanceStore(),
          fixture: _provenanceFixture,
          runId: 'bad/run',
        ),
        throwsArgumentError,
      );
      await expectLater(
        suite.verifyAnchorStore(
          store: InMemoryPluginRecoveryProvenanceAnchorStore(),
          chainId: ' ',
          runId: 'safe',
        ),
        throwsArgumentError,
      );
    });
  });

  group('PluginRecoveryProvenanceAnchorPublisher', () {
    test('publishes signed checkpoints and detects an unanchored tail', () async {
      final provenanceStore = InMemoryPluginRecoveryProvenanceStore();
      final anchorStore = InMemoryPluginRecoveryProvenanceAnchorStore();
      final appender = PluginRecoveryProvenanceAppender(
        store: provenanceStore,
        digestProvider: _Digest(),
        digestAlgorithm: 'test-digest',
      );
      Future<void> appendEvent(String id, int day) => appender.append(
        eventId: id,
        action: PluginRecoveryProvenanceAction.exported,
        occurredAt: DateTime.utc(2026, 1, day),
        sourceDeploymentId: 'deployment-a',
        packageId: 'package-a',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
      );

      await appendEvent('event-1', 1);
      final publisher = PluginRecoveryProvenanceAnchorPublisher(
        chainId: 'chain-a',
        provenanceStore: provenanceStore,
        anchorStore: anchorStore,
        signer: _Signer(),
        signerKeyId: 'anchor-key',
        signatureAlgorithm: 'test-signature',
      );
      await publisher.publish(anchoredAt: DateTime.utc(2026, 1, 1, 1));

      final verifier = PluginRecoveryProvenanceAnchorVerifier(
        chainId: 'chain-a',
        provenanceStore: provenanceStore,
        anchorStore: anchorStore,
        signatureVerifier: _SignatureVerifier(),
      );
      final current = await verifier.verify();
      expect(current.disposition, PluginRecoveryProvenanceAnchorDisposition.valid);
      expect(current.isCurrent, isTrue);

      await appendEvent('event-2', 2);
      final stale = await verifier.verify();
      expect(stale.isValid, isTrue);
      expect(stale.isCurrent, isFalse);
      expect(stale.latestAnchoredProvenanceSequence, 1);
      expect(stale.currentProvenanceSequence, 2);

      await publisher.publish(anchoredAt: DateTime.utc(2026, 1, 2, 1));
      expect((await verifier.verify()).isCurrent, isTrue);
    });

    test('detects a modified signed checkpoint', () async {
      final provenanceStore = InMemoryPluginRecoveryProvenanceStore();
      await PluginRecoveryProvenanceAppender(
        store: provenanceStore,
        digestProvider: _Digest(),
        digestAlgorithm: 'test-digest',
      ).append(
        eventId: 'event-1',
        action: PluginRecoveryProvenanceAction.exported,
        occurredAt: DateTime.utc(2026, 1, 1),
        sourceDeploymentId: 'deployment-a',
        packageId: 'package-a',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
      );
      final anchorStore = _TamperedAnchorStore();
      final publisher = PluginRecoveryProvenanceAnchorPublisher(
        chainId: 'chain-a',
        provenanceStore: provenanceStore,
        anchorStore: anchorStore,
        signer: _Signer(),
        signerKeyId: 'anchor-key',
        signatureAlgorithm: 'test-signature',
      );
      final anchor = await publisher.publish(
        anchoredAt: DateTime.utc(2026, 1, 1, 1),
      );
      anchorStore.anchor = PluginRecoveryProvenanceAnchor(
        chainId: anchor.chainId,
        anchorSequence: anchor.anchorSequence,
        provenanceSequence: anchor.provenanceSequence,
        headEventDigestAlgorithm: anchor.headEventDigestAlgorithm,
        headEventDigest: 'tampered-head',
        anchoredAt: anchor.anchoredAt,
        signerKeyId: anchor.signerKeyId,
        signatureAlgorithm: anchor.signatureAlgorithm,
        signature: anchor.signature,
      );

      final report = await PluginRecoveryProvenanceAnchorVerifier(
        chainId: 'chain-a',
        provenanceStore: provenanceStore,
        anchorStore: anchorStore,
        signatureVerifier: _SignatureVerifier(),
      ).verify();
      expect(report.disposition,
        PluginRecoveryProvenanceAnchorDisposition.provenanceDigestMismatch);

      anchorStore.anchor = PluginRecoveryProvenanceAnchor(
        chainId: anchor.chainId,
        anchorSequence: anchor.anchorSequence,
        provenanceSequence: anchor.provenanceSequence,
        headEventDigestAlgorithm: anchor.headEventDigestAlgorithm,
        headEventDigest: anchor.headEventDigest,
        anchoredAt: anchor.anchoredAt,
        signerKeyId: anchor.signerKeyId,
        signatureAlgorithm: anchor.signatureAlgorithm,
        signature: 'invalid-signature',
      );
      final invalidSignature = await PluginRecoveryProvenanceAnchorVerifier(
        chainId: 'chain-a',
        provenanceStore: provenanceStore,
        anchorStore: anchorStore,
        signatureVerifier: _SignatureVerifier(),
      ).verify();
      expect(invalidSignature.disposition,
        PluginRecoveryProvenanceAnchorDisposition.invalidSignature);
    });
  });
}

final class _Digest implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({
    required String algorithm,
    required String canonicalPayload,
  }) async => '$algorithm:${canonicalPayload.length}:${canonicalPayload.hashCode}';
}

final class _TamperedAnchorStore implements PluginRecoveryProvenanceAnchorStore {
  PluginRecoveryProvenanceAnchor? anchor;

  @override
  Future<List<PluginRecoveryProvenanceAnchor>> readAll(String chainId) async =>
      anchor == null ? const [] : [anchor!];

  @override
  Future<bool> appendIfSequenceMatches({
    required String chainId,
    required int expectedAnchorSequence,
    required PluginRecoveryProvenanceAnchor anchor,
  }) async {
    if (this.anchor != null || expectedAnchorSequence != 0) return false;
    this.anchor = anchor;
    return true;
  }
}

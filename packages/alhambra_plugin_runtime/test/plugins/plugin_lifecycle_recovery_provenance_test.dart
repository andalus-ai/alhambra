import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final class _Digest implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({
    required String algorithm,
    required String canonicalPayload,
  }) async => '$algorithm:${canonicalPayload.length}:${canonicalPayload.hashCode}';
}

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

final class _FixedProvenanceStore implements PluginRecoveryProvenanceStore {
  _FixedProvenanceStore(this.events);

  final List<PluginRecoveryProvenanceEvent> events;

  @override
  Future<List<PluginRecoveryProvenanceEvent>> readAll() async => events;

  @override
  Future<bool> appendIfHeadMatches({
    required int expectedSequence,
    required String? expectedHeadDigest,
    required PluginRecoveryProvenanceEvent event,
  }) async => false;
}

void main() {
  group('Plugin recovery provenance', () {
    test('appends and verifies a signed, linked event chain', () async {
      final store = InMemoryPluginRecoveryProvenanceStore();
      final appender = PluginRecoveryProvenanceAppender(
        store: store,
        digestProvider: _Digest(),
        digestAlgorithm: 'test-digest',
        signer: _Signer(),
        signerKeyId: 'recovery-key-1',
        signatureAlgorithm: 'test-signature',
      );

      final first = await appender.append(
        eventId: 'event-1',
        action: PluginRecoveryProvenanceAction.exported,
        occurredAt: DateTime.utc(2026, 1, 1),
        sourceDeploymentId: 'deployment-a',
        packageId: 'package-1',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
      );
      final second = await appender.append(
        eventId: 'event-2',
        action: PluginRecoveryProvenanceAction.imported,
        occurredAt: DateTime.utc(2026, 1, 2),
        sourceDeploymentId: 'deployment-b',
        packageId: 'package-1',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
      );

      expect(second.sequence, 2);
      expect(second.previousEventDigest, first.eventDigest);
      final report = await PluginRecoveryProvenanceVerifier(
        store: store,
        digestProvider: _Digest(),
        signatureVerifier: _SignatureVerifier(),
        requireSignatures: true,
      ).verify();

      expect(report.disposition, PluginRecoveryProvenanceDisposition.valid);
      expect(report.verifiedEvents, 2);
    });

    test('detects a broken predecessor link', () async {
      final invalid = PluginRecoveryProvenanceEvent(
        eventId: 'event-2',
        sequence: 2,
        action: PluginRecoveryProvenanceAction.imported,
        occurredAt: DateTime.utc(2026, 1, 2),
        sourceDeploymentId: 'deployment-b',
        packageId: 'package-1',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
        previousEventDigest: 'wrong-head',
        eventDigestAlgorithm: 'test-digest',
        eventDigest: 'unused',
      );
      final report = await PluginRecoveryProvenanceVerifier(
        store: _FixedProvenanceStore([invalid]),
        digestProvider: _Digest(),
      ).verify();

      expect(report.disposition, PluginRecoveryProvenanceDisposition.sequenceGap);
      expect(report.failingEventId, 'event-2');
    });

    test('fails closed when a required signature is absent', () async {
      final store = InMemoryPluginRecoveryProvenanceStore();
      await PluginRecoveryProvenanceAppender(
        store: store,
        digestProvider: _Digest(),
        digestAlgorithm: 'test-digest',
      ).append(
        eventId: 'event-1',
        action: PluginRecoveryProvenanceAction.verified,
        occurredAt: DateTime.utc(2026, 1, 1),
        sourceDeploymentId: 'deployment-a',
        packageId: 'package-1',
        packageDigestAlgorithm: 'sha256',
        packageDigest: 'package-digest',
      );

      final report = await PluginRecoveryProvenanceVerifier(
        store: store,
        digestProvider: _Digest(),
        requireSignatures: true,
      ).verify();

      expect(report.disposition, PluginRecoveryProvenanceDisposition.missingSignature);
    });
  });

  group('Plugin recovery signing key history', () {
    test('separates validity at signing time from current revocation', () async {
      final store = InMemoryPluginRecoverySigningKeyHistoryStore();
      final activatedAt = DateTime.utc(2026, 1, 1);
      final revokedAt = DateTime.utc(2026, 2, 1);
      expect(await store.appendIfSequenceMatches(
        expectedSequence: 0,
        event: PluginRecoverySigningKeyLifecycleEvent(
          eventId: 'key-event-1',
          sequence: 1,
          keyId: 'key-1',
          algorithm: 'ed25519',
          principalId: 'publisher-a',
          action: PluginRecoverySigningKeyLifecycleAction.activated,
          occurredAt: activatedAt,
          validFrom: activatedAt,
        ),
      ), isTrue);
      expect(await store.appendIfSequenceMatches(
        expectedSequence: 1,
        event: PluginRecoverySigningKeyLifecycleEvent(
          eventId: 'key-event-2',
          sequence: 2,
          keyId: 'key-1',
          algorithm: 'ed25519',
          principalId: 'publisher-a',
          action: PluginRecoverySigningKeyLifecycleAction.revoked,
          occurredAt: revokedAt,
          reasonCode: 'key-compromise',
        ),
      ), isTrue);

      final inspector = PluginRecoverySigningKeyHistoryInspector(store: store);
      final beforeRevocation = await inspector.assess(
        keyId: 'key-1',
        signingTime: DateTime.utc(2026, 1, 15),
      );
      final afterRevocation = await inspector.assess(
        keyId: 'key-1',
        signingTime: DateTime.utc(2026, 2, 15),
      );

      expect(beforeRevocation.wasValidAtSigningTime, isTrue);
      expect(beforeRevocation.currentlyRevoked, isTrue);
      expect(afterRevocation.disposition,
        PluginRecoverySigningKeyAssessmentDisposition.revokedAtSigningTime);
    });
  });
}

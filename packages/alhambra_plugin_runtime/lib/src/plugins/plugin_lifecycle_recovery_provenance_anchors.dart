import 'dart:convert';

import 'plugin_lifecycle_recovery_provenance.dart';
import 'plugin_lifecycle_recovery_archive_package_authenticity.dart';

/// Immutable signed checkpoint of a provenance chain head.
final class PluginRecoveryProvenanceAnchor {
  final String chainId;
  final int anchorSequence;
  final int provenanceSequence;
  final String headEventDigestAlgorithm;
  final String headEventDigest;
  final DateTime anchoredAt;
  final String signerKeyId;
  final String signatureAlgorithm;
  final String signature;

  PluginRecoveryProvenanceAnchor({
    required this.chainId,
    required this.anchorSequence,
    required this.provenanceSequence,
    required this.headEventDigestAlgorithm,
    required this.headEventDigest,
    required DateTime anchoredAt,
    required this.signerKeyId,
    required this.signatureAlgorithm,
    required this.signature,
  }) : anchoredAt = anchoredAt.toUtc() {
    for (final value in [
      chainId,
      headEventDigestAlgorithm,
      headEventDigest,
      signerKeyId,
      signatureAlgorithm,
      signature,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('Anchor identity and signature fields must not be empty.');
      }
    }
    if (anchorSequence < 1) throw ArgumentError.value(anchorSequence, 'anchorSequence');
    if (provenanceSequence < 1) {
      throw ArgumentError.value(provenanceSequence, 'provenanceSequence');
    }
  }
}

final class PluginRecoveryProvenanceAnchorCodec {
  const PluginRecoveryProvenanceAnchorCodec();

  String encodePayload(PluginRecoveryProvenanceAnchor anchor) => jsonEncode({
    'domain': 'alhambra.recovery-provenance-anchor.v1',
    'chainId': anchor.chainId,
    'anchorSequence': anchor.anchorSequence,
    'provenanceSequence': anchor.provenanceSequence,
    'headEventDigestAlgorithm': anchor.headEventDigestAlgorithm,
    'headEventDigest': anchor.headEventDigest,
    'anchoredAt': anchor.anchoredAt.toUtc().toIso8601String(),
    'signerKeyId': anchor.signerKeyId,
    'signatureAlgorithm': anchor.signatureAlgorithm,
  });
}

/// Host-backed store must append atomically and preserve all prior anchors.
abstract interface class PluginRecoveryProvenanceAnchorStore {
  Future<List<PluginRecoveryProvenanceAnchor>> readAll(String chainId);

  Future<bool> appendIfSequenceMatches({
    required String chainId,
    required int expectedAnchorSequence,
    required PluginRecoveryProvenanceAnchor anchor,
  });
}

final class InMemoryPluginRecoveryProvenanceAnchorStore
    implements PluginRecoveryProvenanceAnchorStore {
  final Map<String, List<PluginRecoveryProvenanceAnchor>> _anchors = {};

  @override
  Future<List<PluginRecoveryProvenanceAnchor>> readAll(String chainId) async =>
      List.unmodifiable(_anchors[chainId] ?? const []);

  @override
  Future<bool> appendIfSequenceMatches({
    required String chainId,
    required int expectedAnchorSequence,
    required PluginRecoveryProvenanceAnchor anchor,
  }) async {
    final entries = _anchors.putIfAbsent(chainId, () => []);
    if (anchor.chainId != chainId ||
        entries.length != expectedAnchorSequence ||
        anchor.anchorSequence != expectedAnchorSequence + 1 ||
        entries.any((item) => item.anchorSequence == anchor.anchorSequence)) {
      return false;
    }
    entries.add(anchor);
    return true;
  }
}

final class PluginRecoveryProvenanceAnchorPublisher {
  final String chainId;
  final PluginRecoveryProvenanceStore provenanceStore;
  final PluginRecoveryProvenanceAnchorStore anchorStore;
  final PluginRecoveryArchivePackageSigner signer;
  final String signerKeyId;
  final String signatureAlgorithm;
  final PluginRecoveryProvenanceAnchorCodec codec;

  const PluginRecoveryProvenanceAnchorPublisher({
    required this.chainId,
    required this.provenanceStore,
    required this.anchorStore,
    required this.signer,
    required this.signerKeyId,
    required this.signatureAlgorithm,
    this.codec = const PluginRecoveryProvenanceAnchorCodec(),
  });

  Future<PluginRecoveryProvenanceAnchor> publish({
    required DateTime anchoredAt,
  }) async {
    if (chainId.trim().isEmpty ||
        signerKeyId.trim().isEmpty ||
        signatureAlgorithm.trim().isEmpty) {
      throw ArgumentError('Chain and signing identity fields must not be empty.');
    }
    final events = await provenanceStore.readAll();
    if (events.isEmpty) throw StateError('Cannot anchor an empty provenance chain.');
    final head = events.last;
    final existing = await anchorStore.readAll(chainId);
    if (existing.isNotEmpty) {
      final latest = existing.last;
      if (latest.provenanceSequence > head.sequence) {
        throw StateError('Stored anchor is ahead of the current provenance chain.');
      }
      if (latest.provenanceSequence == head.sequence &&
          latest.headEventDigest == head.eventDigest) {
        throw StateError('The current provenance head is already anchored.');
      }
    }
    final unsigned = PluginRecoveryProvenanceAnchor(
      chainId: chainId,
      anchorSequence: existing.length + 1,
      provenanceSequence: head.sequence,
      headEventDigestAlgorithm: head.eventDigestAlgorithm,
      headEventDigest: head.eventDigest,
      anchoredAt: anchoredAt,
      signerKeyId: signerKeyId,
      signatureAlgorithm: signatureAlgorithm,
      signature: 'pending',
    );
    final signature = await signer.sign(
      algorithm: signatureAlgorithm,
      keyId: signerKeyId,
      canonicalPayload: codec.encodePayload(unsigned),
    );
    final anchor = PluginRecoveryProvenanceAnchor(
      chainId: chainId,
      anchorSequence: unsigned.anchorSequence,
      provenanceSequence: unsigned.provenanceSequence,
      headEventDigestAlgorithm: unsigned.headEventDigestAlgorithm,
      headEventDigest: unsigned.headEventDigest,
      anchoredAt: unsigned.anchoredAt,
      signerKeyId: signerKeyId,
      signatureAlgorithm: signatureAlgorithm,
      signature: signature,
    );
    final appended = await anchorStore.appendIfSequenceMatches(
      chainId: chainId,
      expectedAnchorSequence: existing.length,
      anchor: anchor,
    );
    if (!appended) {
      throw StateError('Anchor history changed while publishing; read the latest head and retry.');
    }
    return anchor;
  }
}

enum PluginRecoveryProvenanceAnchorDisposition {
  valid,
  noAnchors,
  sequenceGap,
  chainIdMismatch,
  provenanceHeadMissing,
  provenanceDigestMismatch,
  invalidSignature,
}

final class PluginRecoveryProvenanceAnchorVerificationReport {
  final PluginRecoveryProvenanceAnchorDisposition disposition;
  final int verifiedAnchors;
  final int? failingAnchorSequence;
  final int? latestAnchoredProvenanceSequence;
  final int currentProvenanceSequence;

  const PluginRecoveryProvenanceAnchorVerificationReport({
    required this.disposition,
    required this.verifiedAnchors,
    required this.currentProvenanceSequence,
    this.failingAnchorSequence,
    this.latestAnchoredProvenanceSequence,
  });

  bool get isValid =>
      disposition == PluginRecoveryProvenanceAnchorDisposition.valid ||
      disposition == PluginRecoveryProvenanceAnchorDisposition.noAnchors;
  bool get isCurrent =>
      isValid && latestAnchoredProvenanceSequence == currentProvenanceSequence;
}

final class PluginRecoveryProvenanceAnchorVerifier {
  final String chainId;
  final PluginRecoveryProvenanceStore provenanceStore;
  final PluginRecoveryProvenanceAnchorStore anchorStore;
  final PluginRecoveryArchivePackageSignatureVerifier signatureVerifier;
  final PluginRecoveryProvenanceAnchorCodec codec;

  const PluginRecoveryProvenanceAnchorVerifier({
    required this.chainId,
    required this.provenanceStore,
    required this.anchorStore,
    required this.signatureVerifier,
    this.codec = const PluginRecoveryProvenanceAnchorCodec(),
  });

  Future<PluginRecoveryProvenanceAnchorVerificationReport> verify() async {
    final events = await provenanceStore.readAll();
    final anchors = await anchorStore.readAll(chainId);
    if (anchors.isEmpty) {
      return PluginRecoveryProvenanceAnchorVerificationReport(
        disposition: PluginRecoveryProvenanceAnchorDisposition.noAnchors,
        verifiedAnchors: 0,
        currentProvenanceSequence: events.length,
      );
    }
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      PluginRecoveryProvenanceAnchorDisposition? failure;
      if (anchor.chainId != chainId) {
        failure = PluginRecoveryProvenanceAnchorDisposition.chainIdMismatch;
      } else if (anchor.anchorSequence != i + 1) {
        failure = PluginRecoveryProvenanceAnchorDisposition.sequenceGap;
      } else if (anchor.provenanceSequence > events.length) {
        failure = PluginRecoveryProvenanceAnchorDisposition.provenanceHeadMissing;
      } else if (events[anchor.provenanceSequence - 1].eventDigest !=
          anchor.headEventDigest) {
        failure = PluginRecoveryProvenanceAnchorDisposition.provenanceDigestMismatch;
      }
      if (failure != null) {
        return PluginRecoveryProvenanceAnchorVerificationReport(
          disposition: failure,
          verifiedAnchors: i,
          failingAnchorSequence: anchor.anchorSequence,
          latestAnchoredProvenanceSequence: i == 0
              ? null
              : anchors[i - 1].provenanceSequence,
          currentProvenanceSequence: events.length,
        );
      }
      final valid = await signatureVerifier.verify(
        algorithm: anchor.signatureAlgorithm,
        keyId: anchor.signerKeyId,
        canonicalPayload: codec.encodePayload(anchor),
        signature: anchor.signature,
      );
      if (!valid) {
        return PluginRecoveryProvenanceAnchorVerificationReport(
          disposition: PluginRecoveryProvenanceAnchorDisposition.invalidSignature,
          verifiedAnchors: i,
          failingAnchorSequence: anchor.anchorSequence,
          latestAnchoredProvenanceSequence: i == 0
              ? null
              : anchors[i - 1].provenanceSequence,
          currentProvenanceSequence: events.length,
        );
      }
    }
    return PluginRecoveryProvenanceAnchorVerificationReport(
      disposition: PluginRecoveryProvenanceAnchorDisposition.valid,
      verifiedAnchors: anchors.length,
      latestAnchoredProvenanceSequence: anchors.last.provenanceSequence,
      currentProvenanceSequence: events.length,
    );
  }
}

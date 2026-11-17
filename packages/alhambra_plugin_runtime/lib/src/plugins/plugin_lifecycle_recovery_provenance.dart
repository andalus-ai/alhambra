import 'dart:convert';

import 'plugin_lifecycle_recovery_archive_package_authenticity.dart';
import 'plugin_lifecycle_recovery_job_archive_integrity.dart';

enum PluginRecoveryProvenanceAction {
  packageCreated,
  exported,
  imported,
  restored,
  migrated,
  verified,
}

enum PluginRecoveryProvenanceDisposition {
  valid,
  empty,
  sequenceGap,
  duplicateEventId,
  previousDigestMismatch,
  eventDigestMismatch,
  unsupportedSchema,
  missingSignature,
  invalidSignature,
}

final class PluginRecoveryProvenanceEvent {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String eventId;
  final int sequence;
  final PluginRecoveryProvenanceAction action;
  final DateTime occurredAt;
  final String sourceDeploymentId;
  final String? actorId;
  final String packageId;
  final String packageDigestAlgorithm;
  final String packageDigest;
  final String? signerKeyId;
  final String? signatureAlgorithm;
  final String? signature;
  final String? previousEventDigest;
  final String eventDigestAlgorithm;
  final String eventDigest;

  PluginRecoveryProvenanceEvent({
    this.schemaVersion = currentSchemaVersion,
    required this.eventId,
    required this.sequence,
    required this.action,
    required DateTime occurredAt,
    required this.sourceDeploymentId,
    this.actorId,
    required this.packageId,
    required this.packageDigestAlgorithm,
    required this.packageDigest,
    this.signerKeyId,
    this.signatureAlgorithm,
    this.signature,
    this.previousEventDigest,
    required this.eventDigestAlgorithm,
    required this.eventDigest,
  }) : occurredAt = occurredAt.toUtc() {
    for (final entry in {
      'eventId': eventId,
      'sourceDeploymentId': sourceDeploymentId,
      'packageId': packageId,
      'packageDigestAlgorithm': packageDigestAlgorithm,
      'packageDigest': packageDigest,
      'eventDigestAlgorithm': eventDigestAlgorithm,
      'eventDigest': eventDigest,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(entry.value, entry.key);
      }
    }
    if (schemaVersion < 1) throw ArgumentError.value(schemaVersion, 'schemaVersion');
    if (sequence < 1) throw ArgumentError.value(sequence, 'sequence');
    if ((signerKeyId == null) != (signatureAlgorithm == null) ||
        (signerKeyId == null) != (signature == null)) {
      throw ArgumentError('Signer key, signature algorithm and signature must be supplied together.');
    }
    if (signerKeyId != null &&
        [signerKeyId!, signatureAlgorithm!, signature!].any((v) => v.trim().isEmpty)) {
      throw ArgumentError('Signature metadata must not be empty.');
    }
    if (sequence == 1 && previousEventDigest != null) {
      throw ArgumentError('The first event cannot have a predecessor digest.');
    }
    if (sequence > 1 &&
        (previousEventDigest == null || previousEventDigest!.trim().isEmpty)) {
      throw ArgumentError('Events after the first require a predecessor digest.');
    }
  }
}

final class PluginRecoveryProvenanceCodec {
  const PluginRecoveryProvenanceCodec();

  String encodePayload(PluginRecoveryProvenanceEvent event) => jsonEncode({
    'schemaVersion': event.schemaVersion,
    'eventId': event.eventId,
    'sequence': event.sequence,
    'action': event.action.name,
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'sourceDeploymentId': event.sourceDeploymentId,
    'actorId': event.actorId,
    'packageId': event.packageId,
    'packageDigestAlgorithm': event.packageDigestAlgorithm,
    'packageDigest': event.packageDigest,
    'signerKeyId': event.signerKeyId,
    'signatureAlgorithm': event.signatureAlgorithm,
    'previousEventDigest': event.previousEventDigest,
    'eventDigestAlgorithm': event.eventDigestAlgorithm,
  });

  String encodeSignaturePayload(PluginRecoveryProvenanceEvent event) => jsonEncode({
    'domain': 'alhambra.recovery-provenance-event.signature.v1',
    'payload': jsonDecode(encodePayload(event)),
    'eventDigest': event.eventDigest,
  });

  String encode(PluginRecoveryProvenanceEvent event) => jsonEncode({
    'payload': jsonDecode(encodePayload(event)),
    'eventDigest': event.eventDigest,
    'signature': event.signature,
  });
}

/// Host storage must append atomically against the expected current head.
/// Implementations shared by multiple processes must enforce this in durable
/// storage (for example, with a transaction or compare-and-set).
abstract interface class PluginRecoveryProvenanceStore {
  Future<List<PluginRecoveryProvenanceEvent>> readAll();

  Future<bool> appendIfHeadMatches({
    required int expectedSequence,
    required String? expectedHeadDigest,
    required PluginRecoveryProvenanceEvent event,
  });
}

final class InMemoryPluginRecoveryProvenanceStore
    implements PluginRecoveryProvenanceStore {
  final List<PluginRecoveryProvenanceEvent> _events = [];

  @override
  Future<List<PluginRecoveryProvenanceEvent>> readAll() async =>
      List.unmodifiable(_events);

  @override
  Future<bool> appendIfHeadMatches({
    required int expectedSequence,
    required String? expectedHeadDigest,
    required PluginRecoveryProvenanceEvent event,
  }) async {
    final head = _events.isEmpty ? null : _events.last;
    if (_events.length != expectedSequence ||
        (head?.eventDigest != expectedHeadDigest) ||
        event.sequence != expectedSequence + 1 ||
        _events.any((item) => item.eventId == event.eventId)) {
      return false;
    }
    _events.add(event);
    return true;
  }
}

final class PluginRecoveryProvenanceAppender {
  final PluginRecoveryProvenanceStore store;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final String digestAlgorithm;
  final PluginRecoveryArchivePackageSigner? signer;
  final String? signerKeyId;
  final String? signatureAlgorithm;
  final PluginRecoveryProvenanceCodec codec;

  const PluginRecoveryProvenanceAppender({
    required this.store,
    required this.digestProvider,
    required this.digestAlgorithm,
    this.signer,
    this.signerKeyId,
    this.signatureAlgorithm,
    this.codec = const PluginRecoveryProvenanceCodec(),
  });

  Future<PluginRecoveryProvenanceEvent> append({
    required String eventId,
    required PluginRecoveryProvenanceAction action,
    required DateTime occurredAt,
    required String sourceDeploymentId,
    required String packageId,
    required String packageDigestAlgorithm,
    required String packageDigest,
    String? actorId,
    String? previousEventDigest,
  }) async {
    if ((signer == null) != (signerKeyId == null) ||
        (signer == null) != (signatureAlgorithm == null)) {
      throw ArgumentError('Signer, signerKeyId and signatureAlgorithm must be configured together.');
    }
    final events = await store.readAll();
    final head = events.isEmpty ? null : events.last;
    if (previousEventDigest != null && previousEventDigest != head?.eventDigest) {
      throw StateError('The supplied predecessor digest is not the current chain head.');
    }
    final sequence = events.length + 1;
    final unsigned = PluginRecoveryProvenanceEvent(
      eventId: eventId,
      sequence: sequence,
      action: action,
      occurredAt: occurredAt,
      sourceDeploymentId: sourceDeploymentId,
      actorId: actorId,
      packageId: packageId,
      packageDigestAlgorithm: packageDigestAlgorithm,
      packageDigest: packageDigest,
      signerKeyId: signerKeyId,
      signatureAlgorithm: signatureAlgorithm,
      signature: signer == null ? null : 'pending',
      previousEventDigest: head?.eventDigest,
      eventDigestAlgorithm: digestAlgorithm,
      eventDigest: 'pending',
    );
    final eventPayload = codec.encodePayload(unsigned);
    final eventDigest = await digestProvider.digest(
      algorithm: digestAlgorithm,
      canonicalPayload: eventPayload,
    );
    final digestEvent = PluginRecoveryProvenanceEvent(
      eventId: eventId,
      sequence: sequence,
      action: action,
      occurredAt: occurredAt,
      sourceDeploymentId: sourceDeploymentId,
      actorId: actorId,
      packageId: packageId,
      packageDigestAlgorithm: packageDigestAlgorithm,
      packageDigest: packageDigest,
      signerKeyId: signerKeyId,
      signatureAlgorithm: signatureAlgorithm,
      signature: signer == null ? null : 'pending',
      previousEventDigest: head?.eventDigest,
      eventDigestAlgorithm: digestAlgorithm,
      eventDigest: eventDigest,
    );
    final signature = signer == null ? null : await signer!.sign(
      algorithm: signatureAlgorithm!,
      keyId: signerKeyId!,
      canonicalPayload: codec.encodeSignaturePayload(digestEvent),
    );
    final event = PluginRecoveryProvenanceEvent(
      eventId: eventId,
      sequence: sequence,
      action: action,
      occurredAt: occurredAt,
      sourceDeploymentId: sourceDeploymentId,
      actorId: actorId,
      packageId: packageId,
      packageDigestAlgorithm: packageDigestAlgorithm,
      packageDigest: packageDigest,
      signerKeyId: signerKeyId,
      signatureAlgorithm: signatureAlgorithm,
      signature: signature,
      previousEventDigest: head?.eventDigest,
      eventDigestAlgorithm: digestAlgorithm,
      eventDigest: eventDigest,
    );
    final appended = await store.appendIfHeadMatches(
      expectedSequence: events.length,
      expectedHeadDigest: head?.eventDigest,
      event: event,
    );
    if (!appended) {
      throw StateError('Provenance chain head changed while appending; retry with a new event ID.');
    }
    return event;
  }
}

final class PluginRecoveryProvenanceVerificationReport {
  final PluginRecoveryProvenanceDisposition disposition;
  final int verifiedEvents;
  final String? failingEventId;
  final String? expectedDigest;
  final String? actualDigest;

  const PluginRecoveryProvenanceVerificationReport({
    required this.disposition,
    required this.verifiedEvents,
    this.failingEventId,
    this.expectedDigest,
    this.actualDigest,
  });

  bool get isValid =>
      disposition == PluginRecoveryProvenanceDisposition.valid ||
      disposition == PluginRecoveryProvenanceDisposition.empty;
}

final class PluginRecoveryProvenanceVerifier {
  final PluginRecoveryProvenanceStore store;
  final PluginLifecycleRecoveryJobDigestProvider digestProvider;
  final PluginRecoveryArchivePackageSignatureVerifier? signatureVerifier;
  final bool requireSignatures;
  final PluginRecoveryProvenanceCodec codec;

  const PluginRecoveryProvenanceVerifier({
    required this.store,
    required this.digestProvider,
    this.signatureVerifier,
    this.requireSignatures = false,
    this.codec = const PluginRecoveryProvenanceCodec(),
  });

  Future<PluginRecoveryProvenanceVerificationReport> verify() async {
    final events = await store.readAll();
    if (events.isEmpty) {
      return const PluginRecoveryProvenanceVerificationReport(
        disposition: PluginRecoveryProvenanceDisposition.empty,
        verifiedEvents: 0,
      );
    }
    final ids = <String>{};
    String? previousDigest;
    DateTime? previousTime;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      PluginRecoveryProvenanceDisposition? failure;
      if (event.schemaVersion != PluginRecoveryProvenanceEvent.currentSchemaVersion) {
        failure = PluginRecoveryProvenanceDisposition.unsupportedSchema;
      } else if (event.sequence != i + 1) {
        failure = PluginRecoveryProvenanceDisposition.sequenceGap;
      } else if (!ids.add(event.eventId)) {
        failure = PluginRecoveryProvenanceDisposition.duplicateEventId;
      } else if (event.previousEventDigest != previousDigest) {
        failure = PluginRecoveryProvenanceDisposition.previousDigestMismatch;
      } else if (previousTime != null && event.occurredAt.isBefore(previousTime)) {
        failure = PluginRecoveryProvenanceDisposition.sequenceGap;
      }
      if (failure != null) {
        return _failure(failure, i, event.eventId, verified: i);
      }
      final actual = await digestProvider.digest(
        algorithm: event.eventDigestAlgorithm,
        canonicalPayload: codec.encodePayload(event),
      );
      if (actual != event.eventDigest) {
        return _failure(
          PluginRecoveryProvenanceDisposition.eventDigestMismatch,
          i,
          event.eventId,
          verified: i,
          expected: event.eventDigest,
          actual: actual,
        );
      }
      if (event.signature == null) {
        if (requireSignatures) {
          return _failure(
            PluginRecoveryProvenanceDisposition.missingSignature,
            i,
            event.eventId,
            verified: i,
          );
        }
      } else {
        final verifier = signatureVerifier;
        if (verifier == null) {
          return _failure(
            PluginRecoveryProvenanceDisposition.invalidSignature,
            i,
            event.eventId,
            verified: i,
          );
        }
        final valid = await verifier.verify(
          algorithm: event.signatureAlgorithm!,
          keyId: event.signerKeyId!,
          canonicalPayload: codec.encodeSignaturePayload(event),
          signature: event.signature!,
        );
        if (!valid) {
          return _failure(
            PluginRecoveryProvenanceDisposition.invalidSignature,
            i,
            event.eventId,
            verified: i,
          );
        }
      }
      previousDigest = event.eventDigest;
      previousTime = event.occurredAt;
    }
    return PluginRecoveryProvenanceVerificationReport(
      disposition: PluginRecoveryProvenanceDisposition.valid,
      verifiedEvents: events.length,
    );
  }

  PluginRecoveryProvenanceVerificationReport _failure(
    PluginRecoveryProvenanceDisposition disposition,
    int index,
    String eventId, {
    required int verified,
    String? expected,
    String? actual,
  }) => PluginRecoveryProvenanceVerificationReport(
    disposition: disposition,
    verifiedEvents: verified,
    failingEventId: eventId,
    expectedDigest: expected,
    actualDigest: actual,
  );
}

enum PluginRecoverySigningKeyLifecycleAction {
  activated,
  rotated,
  retired,
  revoked,
}

final class PluginRecoverySigningKeyLifecycleEvent {
  final String eventId;
  final int sequence;
  final String keyId;
  final String algorithm;
  final String principalId;
  final PluginRecoverySigningKeyLifecycleAction action;
  final DateTime occurredAt;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? successorKeyId;
  final String? reasonCode;

  PluginRecoverySigningKeyLifecycleEvent({
    required this.eventId,
    required this.sequence,
    required this.keyId,
    required this.algorithm,
    required this.principalId,
    required this.action,
    required DateTime occurredAt,
    this.validFrom,
    this.validUntil,
    this.successorKeyId,
    this.reasonCode,
  }) : occurredAt = occurredAt.toUtc() {
    for (final value in [eventId, keyId, algorithm, principalId]) {
      if (value.trim().isEmpty) throw ArgumentError('Key lifecycle identity fields must not be empty.');
    }
    if (sequence < 1) throw ArgumentError.value(sequence, 'sequence');
    if (validFrom != null && validUntil != null && validUntil!.isBefore(validFrom!)) {
      throw ArgumentError('validUntil must not precede validFrom.');
    }
    if (action == PluginRecoverySigningKeyLifecycleAction.rotated &&
        (successorKeyId == null || successorKeyId!.trim().isEmpty ||
         successorKeyId == keyId)) {
      throw ArgumentError('A rotation requires a distinct successor key ID.');
    }
    if (action == PluginRecoverySigningKeyLifecycleAction.revoked &&
        (reasonCode == null || reasonCode!.trim().isEmpty)) {
      throw ArgumentError('Revocation requires a reason code.');
    }
  }
}

/// Append-only key lifecycle history. Hosts own durable atomic sequence checks.
abstract interface class PluginRecoverySigningKeyHistoryStore {
  Future<List<PluginRecoverySigningKeyLifecycleEvent>> readAll();

  Future<bool> appendIfSequenceMatches({
    required int expectedSequence,
    required PluginRecoverySigningKeyLifecycleEvent event,
  });
}

final class InMemoryPluginRecoverySigningKeyHistoryStore
    implements PluginRecoverySigningKeyHistoryStore {
  final List<PluginRecoverySigningKeyLifecycleEvent> _events = [];

  @override
  Future<List<PluginRecoverySigningKeyLifecycleEvent>> readAll() async =>
      List.unmodifiable(_events);

  @override
  Future<bool> appendIfSequenceMatches({
    required int expectedSequence,
    required PluginRecoverySigningKeyLifecycleEvent event,
  }) async {
    if (_events.length != expectedSequence ||
        event.sequence != expectedSequence + 1 ||
        _events.any((existing) => existing.eventId == event.eventId)) {
      return false;
    }
    _events.add(event);
    return true;
  }
}

enum PluginRecoverySigningKeyAssessmentDisposition {
  validAtSigningTime,
  unknownKey,
  notYetValid,
  expiredAtSigningTime,
  retiredAtSigningTime,
  revokedAtSigningTime,
}

final class PluginRecoverySigningKeyAssessment {
  final String keyId;
  final PluginRecoverySigningKeyAssessmentDisposition disposition;
  final bool currentlyRevoked;
  final String? successorKeyId;

  const PluginRecoverySigningKeyAssessment({
    required this.keyId,
    required this.disposition,
    required this.currentlyRevoked,
    this.successorKeyId,
  });

  bool get wasValidAtSigningTime =>
      disposition == PluginRecoverySigningKeyAssessmentDisposition.validAtSigningTime;
}

final class PluginRecoverySigningKeyHistoryInspector {
  final PluginRecoverySigningKeyHistoryStore store;

  const PluginRecoverySigningKeyHistoryInspector({required this.store});

  Future<PluginRecoverySigningKeyAssessment> assess({
    required String keyId,
    required DateTime signingTime,
  }) async {
    final events = await store.readAll();
    final history = events.where((event) => event.keyId == keyId).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (history.isEmpty) {
      return PluginRecoverySigningKeyAssessment(
        keyId: keyId,
        disposition: PluginRecoverySigningKeyAssessmentDisposition.unknownKey,
        currentlyRevoked: false,
      );
    }
    final activations = history.where((event) =>
      event.action == PluginRecoverySigningKeyLifecycleAction.activated).toList();
    final activated = activations.isEmpty ? null : activations.first;
    if (activated == null) {
      return PluginRecoverySigningKeyAssessment(
        keyId: keyId,
        disposition: PluginRecoverySigningKeyAssessmentDisposition.unknownKey,
        currentlyRevoked: false,
      );
    }
    final revocations = history.where((event) =>
      event.action == PluginRecoverySigningKeyLifecycleAction.revoked).toList();
    final retirements = history.where((event) =>
      event.action == PluginRecoverySigningKeyLifecycleAction.retired ||
      event.action == PluginRecoverySigningKeyLifecycleAction.rotated).toList();
    final revoked = revocations.isEmpty ? null : revocations.first;
    final retired = retirements.isEmpty ? null : retirements.first;
    final instant = signingTime.toUtc();
    final disposition = instant.isBefore((activated.validFrom ?? activated.occurredAt).toUtc())
        ? PluginRecoverySigningKeyAssessmentDisposition.notYetValid
        : (activated.validUntil != null && instant.isAfter(activated.validUntil!.toUtc()))
            ? PluginRecoverySigningKeyAssessmentDisposition.expiredAtSigningTime
            : (revoked != null && !instant.isBefore(revoked.occurredAt))
                ? PluginRecoverySigningKeyAssessmentDisposition.revokedAtSigningTime
                : (retired != null && !instant.isBefore(retired.occurredAt))
                    ? PluginRecoverySigningKeyAssessmentDisposition.retiredAtSigningTime
                    : PluginRecoverySigningKeyAssessmentDisposition.validAtSigningTime;
    return PluginRecoverySigningKeyAssessment(
      keyId: keyId,
      disposition: disposition,
      currentlyRevoked: revoked != null,
      successorKeyId: retired?.successorKeyId,
    );
  }
}

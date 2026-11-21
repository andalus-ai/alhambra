import 'dart:convert';

import 'plugin_lifecycle_recovery_provenance.dart';
import 'plugin_lifecycle_recovery_provenance_anchors.dart';

/// Read-only filter for an operational provenance timeline.
final class PluginRecoveryProvenanceQuery {
  final String? packageId;
  final String? sourceDeploymentId;
  final String? actorId;
  final String? signerKeyId;
  final Set<PluginRecoveryProvenanceAction> actions;
  final DateTime? occurredAfter;
  final DateTime? occurredBefore;
  final int? beforeSequence;
  final int limit;

  PluginRecoveryProvenanceQuery({
    this.packageId,
    this.sourceDeploymentId,
    this.actorId,
    this.signerKeyId,
    Set<PluginRecoveryProvenanceAction> actions = const {},
    DateTime? occurredAfter,
    DateTime? occurredBefore,
    this.beforeSequence,
    this.limit = 100,
  }) : actions = Set.unmodifiable(actions),
       occurredAfter = occurredAfter?.toUtc(),
       occurredBefore = occurredBefore?.toUtc() {
    for (final value in [packageId, sourceDeploymentId, actorId, signerKeyId]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError('Query filters must not be blank.');
      }
    }
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 500.');
    }
    if (beforeSequence != null && beforeSequence! < 1) {
      throw ArgumentError.value(beforeSequence, 'beforeSequence');
    }
    if (this.occurredAfter != null &&
        this.occurredBefore != null &&
        this.occurredBefore!.isBefore(this.occurredAfter!)) {
      throw ArgumentError('occurredBefore must not precede occurredAfter.');
    }
  }
}

final class PluginRecoveryProvenanceTimelinePage {
  final List<PluginRecoveryProvenanceEvent> events;
  final int? nextBeforeSequence;
  final bool hasMore;

  PluginRecoveryProvenanceTimelinePage({
    required List<PluginRecoveryProvenanceEvent> events,
    required this.nextBeforeSequence,
    required this.hasMore,
  }) : events = List.unmodifiable(events);
}

/// Read-only query service. It never mutates provenance, anchors, or key history.
final class PluginRecoveryProvenanceQueryService {
  final PluginRecoveryProvenanceStore provenanceStore;

  const PluginRecoveryProvenanceQueryService({required this.provenanceStore});

  Future<PluginRecoveryProvenanceTimelinePage> query(
    PluginRecoveryProvenanceQuery query,
  ) async {
    final all = await provenanceStore.readAll();
    final matching = all.where((event) {
      if (query.packageId != null && event.packageId != query.packageId) return false;
      if (query.sourceDeploymentId != null &&
          event.sourceDeploymentId != query.sourceDeploymentId) return false;
      if (query.actorId != null && event.actorId != query.actorId) return false;
      if (query.signerKeyId != null && event.signerKeyId != query.signerKeyId) return false;
      if (query.actions.isNotEmpty && !query.actions.contains(event.action)) return false;
      if (query.occurredAfter != null &&
          event.occurredAt.isBefore(query.occurredAfter!)) return false;
      if (query.occurredBefore != null &&
          event.occurredAt.isAfter(query.occurredBefore!)) return false;
      if (query.beforeSequence != null && event.sequence >= query.beforeSequence!) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final hasMore = matching.length > query.limit;
    final page = matching.take(query.limit).toList(growable: false);
    return PluginRecoveryProvenanceTimelinePage(
      events: page,
      hasMore: hasMore,
      nextBeforeSequence: hasMore && page.isNotEmpty ? page.last.sequence : null,
    );
  }
}

enum PluginRecoveryAuditIncidentSeverity { informational, warning, critical }

enum PluginRecoveryAuditIncidentKind {
  emptyProvenance,
  invalidProvenanceChain,
  missingProvenanceAnchor,
  staleProvenanceAnchor,
  invalidProvenanceAnchor,
  unknownSigningKey,
  signingKeyNotYetValid,
  signingKeyExpired,
  signingKeyRetired,
  signingKeyRevoked,
  currentlyRevokedSigningKey,
}

final class PluginRecoveryAuditIncident {
  final PluginRecoveryAuditIncidentKind kind;
  final PluginRecoveryAuditIncidentSeverity severity;
  final String summary;
  final String? subjectId;

  const PluginRecoveryAuditIncident({
    required this.kind,
    required this.severity,
    required this.summary,
    this.subjectId,
  });
}

final class PluginRecoveryProvenanceAuditReport {
  final String chainId;
  final DateTime generatedAt;
  final int eventCount;
  final int signedEventCount;
  final int unsignedEventCount;
  final int latestSequence;
  final String? latestEventDigest;
  final PluginRecoveryProvenanceVerificationReport chainVerification;
  final PluginRecoveryProvenanceAnchorVerificationReport anchorVerification;
  final List<PluginRecoverySigningKeyAssessment> keyAssessments;
  final List<PluginRecoveryAuditIncident> incidents;

  PluginRecoveryProvenanceAuditReport({
    required this.chainId,
    required DateTime generatedAt,
    required this.eventCount,
    required this.signedEventCount,
    required this.unsignedEventCount,
    required this.latestSequence,
    required this.latestEventDigest,
    required this.chainVerification,
    required this.anchorVerification,
    required List<PluginRecoverySigningKeyAssessment> keyAssessments,
    required List<PluginRecoveryAuditIncident> incidents,
  }) : generatedAt = generatedAt.toUtc(),
       keyAssessments = List.unmodifiable(keyAssessments),
       incidents = List.unmodifiable(incidents);

  bool get isHealthy => incidents.every(
    (incident) => incident.severity == PluginRecoveryAuditIncidentSeverity.informational,
  );

  int get criticalIncidentCount => incidents
      .where((item) => item.severity == PluginRecoveryAuditIncidentSeverity.critical)
      .length;

  int get warningIncidentCount => incidents
      .where((item) => item.severity == PluginRecoveryAuditIncidentSeverity.warning)
      .length;
}

/// Builds a deterministic audit snapshot from host-supplied verification results.
final class PluginRecoveryProvenanceAuditReporter {
  final String chainId;
  final PluginRecoveryProvenanceStore provenanceStore;
  final PluginRecoveryProvenanceVerifier chainVerifier;
  final PluginRecoveryProvenanceAnchorVerifier anchorVerifier;
  final PluginRecoverySigningKeyHistoryInspector keyInspector;

  const PluginRecoveryProvenanceAuditReporter({
    required this.chainId,
    required this.provenanceStore,
    required this.chainVerifier,
    required this.anchorVerifier,
    required this.keyInspector,
  });

  Future<PluginRecoveryProvenanceAuditReport> generate({
    required DateTime generatedAt,
  }) async {
    if (chainId.trim().isEmpty) throw ArgumentError.value(chainId, 'chainId');
    final events = await provenanceStore.readAll();
    final chain = await chainVerifier.verify();
    final anchors = await anchorVerifier.verify();
    final signed = events.where((event) => event.signerKeyId != null).toList();
    final assessments = <PluginRecoverySigningKeyAssessment>[];
    for (final event in signed) {
      assessments.add(await keyInspector.assess(
        keyId: event.signerKeyId!,
        signingTime: event.occurredAt,
      ));
    }

    final incidents = <PluginRecoveryAuditIncident>[];
    if (events.isEmpty) {
      incidents.add(const PluginRecoveryAuditIncident(
        kind: PluginRecoveryAuditIncidentKind.emptyProvenance,
        severity: PluginRecoveryAuditIncidentSeverity.warning,
        summary: 'The provenance chain contains no events.',
      ));
    }
    if (!chain.isValid) {
      incidents.add(PluginRecoveryAuditIncident(
        kind: PluginRecoveryAuditIncidentKind.invalidProvenanceChain,
        severity: PluginRecoveryAuditIncidentSeverity.critical,
        summary: 'Provenance verification failed: ${chain.disposition.name}.',
        subjectId: chain.failingEventId,
      ));
    }
    if (!anchors.isValid) {
      incidents.add(PluginRecoveryAuditIncident(
        kind: PluginRecoveryAuditIncidentKind.invalidProvenanceAnchor,
        severity: PluginRecoveryAuditIncidentSeverity.critical,
        summary: 'Anchor verification failed: ${anchors.disposition.name}.',
        subjectId: anchors.failingAnchorSequence?.toString(),
      ));
    } else if (anchors.disposition == PluginRecoveryProvenanceAnchorDisposition.noAnchors) {
      incidents.add(const PluginRecoveryAuditIncident(
        kind: PluginRecoveryAuditIncidentKind.missingProvenanceAnchor,
        severity: PluginRecoveryAuditIncidentSeverity.warning,
        summary: 'No external provenance checkpoint anchors were found.',
      ));
    } else if (!anchors.isCurrent) {
      incidents.add(PluginRecoveryAuditIncident(
        kind: PluginRecoveryAuditIncidentKind.staleProvenanceAnchor,
        severity: PluginRecoveryAuditIncidentSeverity.warning,
        summary: 'The latest valid anchor covers sequence ${anchors.latestAnchoredProvenanceSequence ?? 0}, while the current chain has ${anchors.currentProvenanceSequence} events.',
      ));
    }

    for (final assessment in assessments) {
      final kind = switch (assessment.disposition) {
        PluginRecoverySigningKeyAssessmentDisposition.validAtSigningTime => null,
        PluginRecoverySigningKeyAssessmentDisposition.unknownKey =>
          PluginRecoveryAuditIncidentKind.unknownSigningKey,
        PluginRecoverySigningKeyAssessmentDisposition.notYetValid =>
          PluginRecoveryAuditIncidentKind.signingKeyNotYetValid,
        PluginRecoverySigningKeyAssessmentDisposition.expiredAtSigningTime =>
          PluginRecoveryAuditIncidentKind.signingKeyExpired,
        PluginRecoverySigningKeyAssessmentDisposition.retiredAtSigningTime =>
          PluginRecoveryAuditIncidentKind.signingKeyRetired,
        PluginRecoverySigningKeyAssessmentDisposition.revokedAtSigningTime =>
          PluginRecoveryAuditIncidentKind.signingKeyRevoked,
      };
      if (kind != null) {
        incidents.add(PluginRecoveryAuditIncident(
          kind: kind,
          severity: PluginRecoveryAuditIncidentSeverity.critical,
          summary: 'Signing key ${assessment.keyId} was ${assessment.disposition.name} for its event.',
          subjectId: assessment.keyId,
        ));
      }
      if (assessment.currentlyRevoked &&
          assessment.disposition != PluginRecoverySigningKeyAssessmentDisposition.revokedAtSigningTime) {
        incidents.add(PluginRecoveryAuditIncident(
          kind: PluginRecoveryAuditIncidentKind.currentlyRevokedSigningKey,
          severity: PluginRecoveryAuditIncidentSeverity.warning,
          summary: 'Signing key ${assessment.keyId} is currently recorded as revoked; historical validity is assessed separately.',
          subjectId: assessment.keyId,
        ));
      }
    }

    return PluginRecoveryProvenanceAuditReport(
      chainId: chainId,
      generatedAt: generatedAt,
      eventCount: events.length,
      signedEventCount: signed.length,
      unsignedEventCount: events.length - signed.length,
      latestSequence: events.isEmpty ? 0 : events.last.sequence,
      latestEventDigest: events.isEmpty ? null : events.last.eventDigest,
      chainVerification: chain,
      anchorVerification: anchors,
      keyAssessments: assessments,
      incidents: incidents,
    );
  }
}

/// Portable JSON representation of an audit snapshot; it contains no secrets.
final class PluginRecoveryProvenanceAuditReportCodec {
  const PluginRecoveryProvenanceAuditReportCodec();

  String encode(PluginRecoveryProvenanceAuditReport report) => jsonEncode({
    'schemaVersion': 1,
    'chainId': report.chainId,
    'generatedAt': report.generatedAt.toUtc().toIso8601String(),
    'summary': {
      'eventCount': report.eventCount,
      'signedEventCount': report.signedEventCount,
      'unsignedEventCount': report.unsignedEventCount,
      'latestSequence': report.latestSequence,
      'latestEventDigest': report.latestEventDigest,
      'isHealthy': report.isHealthy,
      'criticalIncidentCount': report.criticalIncidentCount,
      'warningIncidentCount': report.warningIncidentCount,
    },
    'chainVerification': {
      'disposition': report.chainVerification.disposition.name,
      'verifiedEvents': report.chainVerification.verifiedEvents,
      'failingEventId': report.chainVerification.failingEventId,
      'expectedDigest': report.chainVerification.expectedDigest,
      'actualDigest': report.chainVerification.actualDigest,
    },
    'anchorVerification': {
      'disposition': report.anchorVerification.disposition.name,
      'verifiedAnchors': report.anchorVerification.verifiedAnchors,
      'latestAnchoredProvenanceSequence': report.anchorVerification.latestAnchoredProvenanceSequence,
      'currentProvenanceSequence': report.anchorVerification.currentProvenanceSequence,
      'isCurrent': report.anchorVerification.isCurrent,
    },
    'keyAssessments': report.keyAssessments.map((item) => {
      'keyId': item.keyId,
      'disposition': item.disposition.name,
      'currentlyRevoked': item.currentlyRevoked,
      'successorKeyId': item.successorKeyId,
    }).toList(),
    'incidents': report.incidents.map((item) => {
      'kind': item.kind.name,
      'severity': item.severity.name,
      'summary': item.summary,
      'subjectId': item.subjectId,
    }).toList(),
  });
}

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('PluginRecoveryProvenanceQuery', () {
    test('validates bounds and time range', () {
      expect(() => PluginRecoveryProvenanceQuery(limit: 0), throwsArgumentError);
      expect(() => PluginRecoveryProvenanceQuery(beforeSequence: 0), throwsArgumentError);
      expect(() => PluginRecoveryProvenanceQuery(
        occurredAfter: DateTime.utc(2026, 2),
        occurredBefore: DateTime.utc(2026, 1),
      ), throwsArgumentError);
    });

    test('keeps action filters immutable', () {
      final actions = <PluginRecoveryProvenanceAction>{
        PluginRecoveryProvenanceAction.exported,
      };
      final query = PluginRecoveryProvenanceQuery(actions: actions);
      actions.clear();
      expect(query.actions, contains(PluginRecoveryProvenanceAction.exported));
      expect(() => query.actions.add(PluginRecoveryProvenanceAction.imported),
          throwsUnsupportedError);
    });
  });


  group('PluginRecoveryProvenanceQueryService', () {
    test('filters and paginates newest-first without mutating the store', () async {
      final store = InMemoryPluginRecoveryProvenanceStore();
      for (var sequence = 1; sequence <= 3; sequence++) {
        final event = PluginRecoveryProvenanceEvent(
          eventId: 'event-$sequence',
          sequence: sequence,
          action: sequence == 2
              ? PluginRecoveryProvenanceAction.imported
              : PluginRecoveryProvenanceAction.exported,
          occurredAt: DateTime.utc(2026, 1, sequence),
          sourceDeploymentId: 'deployment-a',
          actorId: 'operator-a',
          packageId: sequence == 3 ? 'package-b' : 'package-a',
          packageDigestAlgorithm: 'test',
          packageDigest: 'package-digest-$sequence',
          previousEventDigest: sequence == 1 ? null : 'event-digest-${sequence - 1}',
          eventDigestAlgorithm: 'test',
          eventDigest: 'event-digest-$sequence',
        );
        expect(await store.appendIfHeadMatches(
          expectedSequence: sequence - 1,
          expectedHeadDigest: sequence == 1 ? null : 'event-digest-${sequence - 1}',
          event: event,
        ), isTrue);
      }
      final service = PluginRecoveryProvenanceQueryService(provenanceStore: store);
      final first = await service.query(PluginRecoveryProvenanceQuery(
        packageId: 'package-a',
        limit: 1,
      ));
      expect(first.events.map((event) => event.sequence), [2]);
      expect(first.hasMore, isTrue);
      expect(first.nextBeforeSequence, 2);
      final second = await service.query(PluginRecoveryProvenanceQuery(
        packageId: 'package-a',
        beforeSequence: first.nextBeforeSequence,
        limit: 1,
      ));
      expect(second.events.map((event) => event.sequence), [1]);
      expect(second.hasMore, isFalse);
      expect((await store.readAll()).length, 3);
    });
  });
\n  group('PluginRecoveryProvenanceAuditReportCodec', () {
    test('exports a versioned JSON snapshot without mutable collections', () {
      final report = PluginRecoveryProvenanceAuditReport(
        chainId: 'chain-a',
        generatedAt: DateTime.utc(2026, 1),
        eventCount: 0,
        signedEventCount: 0,
        unsignedEventCount: 0,
        latestSequence: 0,
        latestEventDigest: null,
        chainVerification: const PluginRecoveryProvenanceVerificationReport(
          disposition: PluginRecoveryProvenanceDisposition.empty,
          verifiedEvents: 0,
        ),
        anchorVerification: const PluginRecoveryProvenanceAnchorVerificationReport(
          disposition: PluginRecoveryProvenanceAnchorDisposition.noAnchors,
          verifiedAnchors: 0,
          currentProvenanceSequence: 0,
        ),
        keyAssessments: const [],
        incidents: const [],
      );
      final encoded = const PluginRecoveryProvenanceAuditReportCodec().encode(report);
      expect(encoded, contains('"schemaVersion":1'));
      expect(encoded, contains('"chainId":"chain-a"'));
      expect(report.isHealthy, isTrue);
    });
  });
}

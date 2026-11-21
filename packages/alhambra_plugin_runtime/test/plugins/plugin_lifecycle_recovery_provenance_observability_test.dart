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

  group('PluginRecoveryProvenanceAuditReportCodec', () {
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

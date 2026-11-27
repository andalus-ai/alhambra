import 'dart:convert';

import 'package:alhambra_plugin_provenance_sqlite/alhambra_plugin_provenance_sqlite.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected database path and event ID.');
  }
  final persistence = SqlitePluginRecoveryProvenancePersistence(args[0]);
  try {
    final event = PluginRecoveryProvenanceEvent(
      eventId: args[1],
      sequence: 1,
      action: PluginRecoveryProvenanceAction.exported,
      occurredAt: DateTime.utc(2026, 1, 1),
      sourceDeploymentId: 'process-test',
      actorId: 'process-test',
      packageId: 'process-test',
      packageDigestAlgorithm: 'test',
      packageDigest: 'package',
      eventDigestAlgorithm: 'test',
      eventDigest: 'digest-${args[1]}',
    );
    final appended = await persistence.provenanceStore.appendIfHeadMatches(
      expectedSequence: 0,
      expectedHeadDigest: null,
      event: event,
    );
    print(jsonEncode({'eventId': args[1], 'appended': appended}));
  } finally {
    persistence.close();
  }
}

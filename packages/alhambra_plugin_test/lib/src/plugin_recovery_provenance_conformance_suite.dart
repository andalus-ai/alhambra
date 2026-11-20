import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

typedef PluginRecoveryProvenanceEventFixture = PluginRecoveryProvenanceEvent
    Function({
  required String eventId,
  required int sequence,
  required String? previousEventDigest,
});

typedef PluginRecoverySigningKeyEventFixture =
    PluginRecoverySigningKeyLifecycleEvent Function({
  required String eventId,
  required int sequence,
});

enum PluginRecoveryAdapterCheckStatus { passed, failed }

final class PluginRecoveryAdapterCheck {
  final String name;
  final PluginRecoveryAdapterCheckStatus status;
  final String detail;

  const PluginRecoveryAdapterCheck({
    required this.name,
    required this.status,
    required this.detail,
  });
}

final class PluginRecoveryAdapterConformanceReport {
  final List<PluginRecoveryAdapterCheck> checks;

  PluginRecoveryAdapterConformanceReport(Iterable<PluginRecoveryAdapterCheck> checks)
      : checks = List.unmodifiable(checks);

  bool get isConformant => checks.every(
    (check) => check.status == PluginRecoveryAdapterCheckStatus.passed,
  );
  int get passedCount => checks.where(
    (check) => check.status == PluginRecoveryAdapterCheckStatus.passed,
  ).length;
  int get failedCount => checks.where(
    (check) => check.status == PluginRecoveryAdapterCheckStatus.failed,
  ).length;
}

/// Exercises append-only provenance, signing-key history, and external anchor
/// stores. Supply fresh disposable stores for each invocation: these contracts
/// intentionally have no delete operation.
///
/// This suite verifies adapter behavior in the current process. It cannot prove
/// multi-process atomicity, durability after power loss, or resistance to
/// privileged storage tampering; production adapters need independent-worker
/// integration tests and operational backup/restore tests.
final class PluginRecoveryProvenanceConformanceSuite {
  const PluginRecoveryProvenanceConformanceSuite();

  Future<PluginRecoveryAdapterConformanceReport> verifyProvenanceStore({
    required PluginRecoveryProvenanceStore store,
    required PluginRecoveryProvenanceEventFixture fixture,
    required String runId,
  }) async {
    _validateRunId(runId);
    final checks = <PluginRecoveryAdapterCheck>[];
    final first = fixture(
      eventId: 'provenance-$runId-event-1',
      sequence: 1,
      previousEventDigest: null,
    );
    final writes = await Future.wait(List.generate(8, (_) => store.appendIfHeadMatches(
      expectedSequence: 0,
      expectedHeadDigest: null,
      event: first,
    )));
    _record(
      checks,
      'provenance append has one concurrent winner',
      writes.where((value) => value).length == 1,
      'Exactly one of eight concurrent appends succeeded.',
      'Expected one successful append, got ${writes.where((value) => value).length}.',
    );

    final events = await store.readAll();
    _record(
      checks,
      'provenance read returns the committed head',
      events.length == 1 &&
          events.single.eventId == first.eventId &&
          events.single.eventDigest == first.eventDigest,
      'The committed event is returned as the only chain entry.',
      'The committed event was missing, duplicated, or changed.',
    );

    final duplicateId = fixture(
      eventId: first.eventId,
      sequence: 2,
      previousEventDigest: first.eventDigest,
    );
    final duplicateAccepted = await store.appendIfHeadMatches(
      expectedSequence: 1,
      expectedHeadDigest: first.eventDigest,
      event: duplicateId,
    );
    _record(
      checks,
      'provenance event IDs are unique',
      !duplicateAccepted && (await store.readAll()).length == 1,
      'Duplicate event ID was rejected without changing the chain.',
      'Duplicate event ID was accepted or altered the chain.',
    );

    final staleHead = fixture(
      eventId: 'provenance-$runId-stale',
      sequence: 2,
      previousEventDigest: 'stale-head',
    );
    final staleAccepted = await store.appendIfHeadMatches(
      expectedSequence: 1,
      expectedHeadDigest: 'stale-head',
      event: staleHead,
    );
    _record(
      checks,
      'provenance append rejects stale head',
      !staleAccepted && (await store.readAll()).length == 1,
      'A stale expected digest was rejected.',
      'The adapter accepted a stale chain head.',
    );
    return PluginRecoveryAdapterConformanceReport(checks);
  }

  Future<PluginRecoveryAdapterConformanceReport> verifySigningKeyHistoryStore({
    required PluginRecoverySigningKeyHistoryStore store,
    required PluginRecoverySigningKeyEventFixture fixture,
    required String runId,
  }) async {
    _validateRunId(runId);
    final checks = <PluginRecoveryAdapterCheck>[];
    final first = fixture(
      eventId: 'key-history-$runId-event-1',
      sequence: 1,
    );
    final writes = await Future.wait(List.generate(8, (_) => store.appendIfSequenceMatches(
      expectedSequence: 0,
      event: first,
    )));
    _record(
      checks,
      'key-history append has one concurrent winner',
      writes.where((value) => value).length == 1,
      'Exactly one of eight concurrent appends succeeded.',
      'Expected one successful append, got ${writes.where((value) => value).length}.',
    );

    final events = await store.readAll();
    _record(
      checks,
      'key-history read returns the committed event',
      events.length == 1 &&
          events.single.eventId == first.eventId &&
          events.single.keyId == first.keyId,
      'The committed key lifecycle event is returned.',
      'The committed key lifecycle event was missing or changed.',
    );

    final duplicateId = fixture(
      eventId: first.eventId,
      sequence: 2,
    );
    final duplicateAccepted = await store.appendIfSequenceMatches(
      expectedSequence: 1,
      event: duplicateId,
    );
    _record(
      checks,
      'key-history event IDs are unique',
      !duplicateAccepted && (await store.readAll()).length == 1,
      'Duplicate key lifecycle event ID was rejected.',
      'Duplicate key lifecycle event ID was accepted.',
    );
    return PluginRecoveryAdapterConformanceReport(checks);
  }

  Future<PluginRecoveryAdapterConformanceReport> verifyAnchorStore({
    required PluginRecoveryProvenanceAnchorStore store,
    required String chainId,
    required String runId,
  }) async {
    _validateRunId(runId);
    if (chainId.trim().isEmpty) throw ArgumentError.value(chainId, 'chainId');
    final checks = <PluginRecoveryAdapterCheck>[];
    final first = _anchor(
      chainId: chainId,
      sequence: 1,
      digest: 'anchor-$runId-head-1',
    );
    final writes = await Future.wait(List.generate(8, (_) => store.appendIfSequenceMatches(
      chainId: chainId,
      expectedAnchorSequence: 0,
      anchor: first,
    )));
    _record(
      checks,
      'anchor append has one concurrent winner',
      writes.where((value) => value).length == 1,
      'Exactly one of eight concurrent anchor appends succeeded.',
      'Expected one successful anchor append, got ${writes.where((value) => value).length}.',
    );

    final anchors = await store.readAll(chainId);
    _record(
      checks,
      'anchor read returns the committed checkpoint',
      anchors.length == 1 &&
          anchors.single.anchorSequence == 1 &&
          anchors.single.headEventDigest == first.headEventDigest,
      'The committed anchor is returned.',
      'The committed anchor was missing, duplicated, or changed.',
    );

    final wrongChain = await store.appendIfSequenceMatches(
      chainId: 'other-$chainId',
      expectedAnchorSequence: 1,
      anchor: _anchor(
        chainId: chainId,
        sequence: 2,
        digest: 'anchor-$runId-head-2',
      ),
    );
    _record(
      checks,
      'anchor store enforces chain identity',
      !wrongChain && (await store.readAll(chainId)).length == 1,
      'An anchor submitted under a different chain ID was rejected.',
      'An anchor was accepted under the wrong chain identity.',
    );
    return PluginRecoveryAdapterConformanceReport(checks);
  }

  PluginRecoveryProvenanceAnchor _anchor({
    required String chainId,
    required int sequence,
    required String digest,
  }) => PluginRecoveryProvenanceAnchor(
    chainId: chainId,
    anchorSequence: sequence,
    provenanceSequence: sequence,
    headEventDigestAlgorithm: 'test-digest',
    headEventDigest: digest,
    anchoredAt: DateTime.utc(2026, 1, 1, 0, sequence),
    signerKeyId: 'test-key',
    signatureAlgorithm: 'test-signature',
    signature: 'test-signature-value',
  );

  void _validateRunId(String runId) {
    if (runId.trim().isEmpty || runId.contains('/') || runId.contains(' ')) {
      throw ArgumentError.value(runId, 'runId', 'Use a non-empty, path-safe unique value.');
    }
  }

  void _record(
    List<PluginRecoveryAdapterCheck> checks,
    String name,
    bool passed,
    String success,
    String failure,
  ) {
    checks.add(PluginRecoveryAdapterCheck(
      name: name,
      status: passed
          ? PluginRecoveryAdapterCheckStatus.passed
          : PluginRecoveryAdapterCheckStatus.failed,
      detail: passed ? success : failure,
    ));
  }
}

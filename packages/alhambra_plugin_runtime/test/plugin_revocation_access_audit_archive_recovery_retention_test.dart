import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verifies ordered archive segments and their hash continuity', () {
    final packages = _packages();
    final set = PluginRevocationAccessAuditArchiveSet(
      manifestId: 'manifest-a', scopeId: 'scope-a', packages: packages,
    );
    final result = PluginRevocationAccessAuditArchiveSetCodec.verify(
      set,
      verifiedCheckpointDigests: packages.map((p) => p.checkpointDigest).toSet(),
    );
    expect(result.valid, isTrue);
    expect(result.verifiedPackages, 3);
    expect(result.verifiedEntries, 3);
    expect(result.toSequence, 3);
  });

  test('detects missing, reordered, duplicate, and untrusted segments', () {
    final packages = _packages();
    PluginRevocationAccessAuditArchiveSetVerification verify(
      List<PluginRevocationAccessAuditArchivePackage> values,
    ) => PluginRevocationAccessAuditArchiveSetCodec.verify(
      PluginRevocationAccessAuditArchiveSet(
        manifestId: 'manifest-a', scopeId: 'scope-a', packages: values,
      ),
      verifiedCheckpointDigests: packages.map((p) => p.checkpointDigest).toSet(),
    );

    expect(verify([packages.first, packages.last]).reason, 'sequence_gap');
    expect(verify([packages.last, packages.first]).reason, 'overlap_or_reorder');
    expect(
      PluginRevocationAccessAuditArchiveSetCodec.verify(
        PluginRevocationAccessAuditArchiveSet(
          manifestId: 'manifest-a', scopeId: 'other-scope', packages: packages,
        ),
        verifiedCheckpointDigests: packages.map((p) => p.checkpointDigest).toSet(),
      ).reason,
      'scope_mismatch',
    );
    expect(verify([packages.first, packages.first]).reason, 'duplicate_package');
    expect(
      PluginRevocationAccessAuditArchiveSetCodec.verify(
        PluginRevocationAccessAuditArchiveSet(
          manifestId: 'manifest-a', scopeId: 'scope-a', packages: packages,
        ),
        verifiedCheckpointDigests: const {},
      ).reason,
      'checkpoint_not_verified',
    );
  });

  test('retention planning requires trusted archive evidence and never authorizes deletion', () async {
    final packages = _packages();
    final authorizer = _RetentionAuthorizer(true);
    final service = PluginRevocationAccessAuditRetentionService(
      authorizer: authorizer,
      checkpointEvidenceVerifier: _CheckpointEvidence(true),
      durabilityVerifier: _ArchiveDurability(true),
      recordMetadataVerifier: _RecordMetadata(DateTime.utc(2026, 1, 1)),
      clock: () => DateTime.utc(2026, 11, 28),
    );
    final plan = await service.plan(
      principal: PluginRevocationOperationsPrincipal(actorId: 'operator'),
      policy: const PluginRevocationAccessAuditRetentionPolicy(
        policyVersion: 'v1',
        minimumAge: Duration(days: 30),
        minimumRetainedSequence: 10,
      ),
      request: PluginRevocationAccessAuditRetentionRequest(
        scopeId: 'scope-a',
        fromSequence: 1,
        throughSequence: 2,
        archiveSet: PluginRevocationAccessAuditArchiveSet(
          manifestId: 'manifest-a', scopeId: 'scope-a', packages: packages,
        ),
      ),
    );
    expect(plan.deletionAuthorized, isFalse);
    expect(plan.disposition, 'plan_only_requires_separate_approval');
    expect(authorizer.calls, 1);
  });

  test('legal hold, retention boundary, age, archive, and authorization fail closed', () async {
    final packages = _packages();
    final request = PluginRevocationAccessAuditRetentionRequest(
      scopeId: 'scope-a', fromSequence: 1, throughSequence: 2,
      archiveSet: PluginRevocationAccessAuditArchiveSet(
        manifestId: 'manifest-a', scopeId: 'scope-a', packages: packages,
      ),
    );
    final service = PluginRevocationAccessAuditRetentionService(
      authorizer: _RetentionAuthorizer(false),
      checkpointEvidenceVerifier: _CheckpointEvidence(true),
      durabilityVerifier: _ArchiveDurability(true),
      clock: () => DateTime.utc(2026, 11, 28),
    );
    final principal = PluginRevocationOperationsPrincipal(actorId: 'operator');
    Future<void> denied(PluginRevocationAccessAuditRetentionPolicy policy) =>
        expectLater(
          service.plan(principal: principal, policy: policy, request: request),
          throwsA(isA<PluginRevocationAccessAuditRetentionDeniedException>()),
        );

    await denied(const PluginRevocationAccessAuditRetentionPolicy(
      policyVersion: 'v1', minimumAge: Duration(days: 30),
      minimumRetainedSequence: 10, legalHold: true,
    ));
    await denied(const PluginRevocationAccessAuditRetentionPolicy(
      policyVersion: 'v1', minimumAge: Duration(days: 30),
      minimumRetainedSequence: 2,
    ));
    await denied(const PluginRevocationAccessAuditRetentionPolicy(
      policyVersion: 'v1', minimumAge: Duration(days: 5000),
      minimumRetainedSequence: 10,
    ));
  });

  test('refuses unavailable archive durability and invalid checkpoint evidence', () async {
    final packages = _packages();
    final service = PluginRevocationAccessAuditRetentionService(
      authorizer: _RetentionAuthorizer(true),
      checkpointEvidenceVerifier: _CheckpointEvidence(false),
      durabilityVerifier: _ArchiveDurability(false),
      recordMetadataVerifier: _RecordMetadata(DateTime.utc(2026, 1, 1)),
      clock: () => DateTime.utc(2026, 11, 28),
    );
    final base = PluginRevocationAccessAuditRetentionRequest(
      scopeId: 'scope-a', fromSequence: 1, throughSequence: 2,
      oldestRecordAt: DateTime.utc(2026, 1, 1),
      archiveSet: PluginRevocationAccessAuditArchiveSet(
        manifestId: 'manifest-a', scopeId: 'scope-a', packages: packages,
      ),
    );
    final policy = const PluginRevocationAccessAuditRetentionPolicy(
      policyVersion: 'v1', minimumAge: Duration(days: 30),
      minimumRetainedSequence: 10,
    );
    await expectLater(
      service.plan(
        principal: PluginRevocationOperationsPrincipal(actorId: 'operator'),
        policy: policy, request: base,
      ),
      throwsA(isA<PluginRevocationAccessAuditRetentionDeniedException>()),
    );
  });
}

List<PluginRevocationAccessAuditArchivePackage> _packages() {
  final first = _entry(1, PluginRevocationAccessAuditChainCodec.genesisHash);
  final second = _entry(2, first.entryHash);
  final third = _entry(3, second.entryHash);
  return [
    _package('segment-1', first, first.previousHash, _hash('1')),
    _package('segment-2', second, first.entryHash, _hash('2')),
    _package('segment-3', third, second.entryHash, _hash('3')),
  ];
}

PluginRevocationAccessAuditArchiveEntry _entry(int sequence, String previous) {
  final audit = PluginRevocationOperationsAccessAudit(
    actorId: 'operator-$sequence',
    scopeId: 'scope-a',
    decision: PluginRevocationOperationsAccessDecision.allowed,
    occurredAt: DateTime.utc(2026, 1, sequence),
    resource: 'audit.read',
  );
  final hash = PluginRevocationAccessAuditChainCodec.hash(
    previousHash: previous,
    canonicalPayload: PluginRevocationAccessAuditChainCodec.canonicalPayload(audit),
  );
  return PluginRevocationAccessAuditArchiveEntry(
    sequence: sequence, previousHash: previous, entryHash: hash, audit: audit,
  );
}

PluginRevocationAccessAuditArchivePackage _package(
  String id, PluginRevocationAccessAuditArchiveEntry entry,
  String previousHash, String checkpointDigest,
) {
  final provisional = PluginRevocationAccessAuditArchivePackage(
    packageId: id, scopeId: 'scope-a',
    fromSequence: entry.sequence, toSequence: entry.sequence,
    previousHash: previousHash, headHash: entry.entryHash,
    createdAt: DateTime.utc(2026, 11, 28),
    checkpointDigest: checkpointDigest, entries: [entry],
    digest: List<String>.filled(64, '0').join(),
  );
  return PluginRevocationAccessAuditArchivePackage(
    packageId: id, scopeId: 'scope-a',
    fromSequence: entry.sequence, toSequence: entry.sequence,
    previousHash: previousHash, headHash: entry.entryHash,
    createdAt: DateTime.utc(2026, 11, 28),
    checkpointDigest: checkpointDigest, entries: [entry],
    digest: PluginRevocationAccessAuditArchiveCodec.calculateDigest(provisional),
  );
}

String _hash(String value) => value.padLeft(64, '0');

final class _RetentionAuthorizer
    implements PluginRevocationAccessAuditRetentionAuthorizer {
  final bool allowed;
  int calls = 0;
  _RetentionAuthorizer(this.allowed);

  @override
  Future<bool> canPlanRetention({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId, required int fromSequence,
    required int throughSequence, required String policyVersion,
  }) async {
    calls++;
    return allowed;
  }
}

final class _CheckpointEvidence
    implements PluginRevocationAccessAuditArchiveCheckpointEvidenceVerifier {
  final bool trusted;
  _CheckpointEvidence(this.trusted);

  @override
  Future<bool> isTrustedCheckpoint({
    required String scopeId, required String checkpointDigest,
  }) async => trusted;
}

final class _ArchiveDurability
    implements PluginRevocationAccessAuditArchiveDurabilityVerifier {
  final bool durable;
  _ArchiveDurability(this.durable);
  @override
  Future<bool> isDurablyRetained({required String manifestId}) async => durable;
}

final class _RecordMetadata
    implements PluginRevocationAccessAuditRetentionRecordMetadataVerifier {
  final DateTime? oldest;
  _RecordMetadata(this.oldest);
  @override
  Future<DateTime?> oldestRecordAt({
    required String scopeId,
    required int fromSequence,
    required int throughSequence,
  }) async => oldest;
}

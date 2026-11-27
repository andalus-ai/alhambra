import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports a contiguous segment ending at an external checkpoint', () async {
    final entries = _entries();
    final exporter = PluginRevocationAccessAuditArchiveExporter(
      chainStore: _Chain(),
      source: _Source(entries),
      checkpointVerifier: const _CheckpointVerifier(),
      clock: () => DateTime.utc(2026, 11, 28),
    );

    final archive = await exporter.export(
      packageId: 'archive-001',
      scopeId: 'workspace-a',
      fromSequence: 1,
      limit: 10,
      checkpoint: _checkpoint(entries),
    );

    expect(archive.fromSequence, 1);
    expect(archive.toSequence, 2);
    expect(archive.headHash, entries.last.entryHash);
    expect(
      PluginRevocationAccessAuditArchiveCodec.verify(archive).valid,
      isTrue,
    );
  });

  test('offline verification detects changed audit data', () async {
    final entries = _entries();
    final exporter = PluginRevocationAccessAuditArchiveExporter(
      chainStore: _Chain(),
      source: _Source(entries),
      checkpointVerifier: const _CheckpointVerifier(),
    );
    final archive = await exporter.export(
      packageId: 'archive-002',
      scopeId: 'workspace-a',
      fromSequence: 1,
      limit: 10,
      checkpoint: _checkpoint(entries),
    );
    final alteredAudit = PluginRevocationOperationsAccessAudit(
      actorId: 'operator-1',
      scopeId: 'workspace-a',
      decision: PluginRevocationOperationsAccessDecision.allowed,
      occurredAt: DateTime.utc(2026, 1, 1),
      resource: 'changed-resource',
    );
    final altered = PluginRevocationAccessAuditArchivePackage(
      packageId: archive.packageId,
      scopeId: archive.scopeId,
      fromSequence: archive.fromSequence,
      toSequence: archive.toSequence,
      previousHash: archive.previousHash,
      headHash: archive.headHash,
      createdAt: archive.createdAt,
      checkpointDigest: archive.checkpointDigest,
      entries: [
        PluginRevocationAccessAuditArchiveEntry(
          sequence: 1,
          previousHash: entries.first.previousHash,
          entryHash: entries.first.entryHash,
          audit: alteredAudit,
        ),
        entries.last,
      ],
      digest: archive.digest,
    );

    expect(
      PluginRevocationAccessAuditArchiveCodec.verify(altered).valid,
      isFalse,
    );
  });

  test('rejects an archive range that cannot reach its checkpoint',
      () async {
    final entries = _entries();
    final exporter = PluginRevocationAccessAuditArchiveExporter(
      chainStore: _Chain(),
      source: _Source(entries),
      checkpointVerifier: const _CheckpointVerifier(),
    );

    await expectLater(
      exporter.export(
        packageId: 'archive-003',
        scopeId: 'workspace-a',
        fromSequence: 1,
        limit: 1,
        checkpoint: _checkpoint(entries),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

List<PluginRevocationAccessAuditArchiveEntry> _entries() {
  final firstAudit = PluginRevocationOperationsAccessAudit(
    actorId: 'operator-1',
    scopeId: 'workspace-a',
    decision: PluginRevocationOperationsAccessDecision.allowed,
    occurredAt: DateTime.utc(2026, 1, 1),
    resource: 'audit.read',
  );
  final secondAudit = PluginRevocationOperationsAccessAudit(
    actorId: 'operator-2',
    scopeId: 'workspace-a',
    decision: PluginRevocationOperationsAccessDecision.denied,
    denialCode: 'forbidden',
    occurredAt: DateTime.utc(2026, 1, 2),
    resource: 'audit.export',
  );
  final firstPayload =
      PluginRevocationAccessAuditChainCodec.canonicalPayload(firstAudit);
  final firstHash = PluginRevocationAccessAuditChainCodec.hash(
    previousHash: PluginRevocationAccessAuditChainCodec.genesisHash,
    canonicalPayload: firstPayload,
  );
  final secondPayload =
      PluginRevocationAccessAuditChainCodec.canonicalPayload(secondAudit);
  final secondHash = PluginRevocationAccessAuditChainCodec.hash(
    previousHash: firstHash,
    canonicalPayload: secondPayload,
  );
  return [
    PluginRevocationAccessAuditArchiveEntry(
      sequence: 1,
      previousHash: PluginRevocationAccessAuditChainCodec.genesisHash,
      entryHash: firstHash,
      audit: firstAudit,
    ),
    PluginRevocationAccessAuditArchiveEntry(
      sequence: 2,
      previousHash: firstHash,
      entryHash: secondHash,
      audit: secondAudit,
    ),
  ];
}

String _hash(String value) => value.padLeft(64, '0');

final class _Chain implements PluginRevocationAccessAuditChainStore {
  @override
  Future<PluginRevocationAccessAuditChainVerification>
      verifyAccessAuditChain({required String scopeId}) async =>
          PluginRevocationAccessAuditChainVerification(
            scopeId: scopeId,
            valid: true,
            entriesVerified: 2,
            headHash: _entries().last.entryHash,
          );
}

final class _Source implements PluginRevocationAccessAuditArchiveSource {
  final List<PluginRevocationAccessAuditArchiveEntry> entries;
  _Source(this.entries);

  @override
  Future<List<PluginRevocationAccessAuditArchiveEntry>> readArchiveEntries({
    required String scopeId,
    required int fromSequence,
    required int limit,
  }) async =>
      entries
          .where((entry) => entry.sequence >= fromSequence)
          .take(limit)
          .toList(growable: false);
}

PluginRevocationAccessAuditCheckpoint _checkpoint(
  List<PluginRevocationAccessAuditArchiveEntry> entries, {
  int sequence = 2,
}) =>
    PluginRevocationAccessAuditCheckpoint(
      scopeId: 'workspace-a',
      sequence: sequence,
      headHash: entries[sequence - 1].entryHash,
      createdAt: DateTime.utc(2026, 11, 28),
      signingKeyId: 'archive-test-key',
      signature: 'trusted-test-signature',
    );

final class _CheckpointVerifier
    implements PluginRevocationAccessAuditCheckpointVerifier {
  const _CheckpointVerifier();

  @override
  Future<bool> verify({
    required String keyId,
    required String canonicalPayload,
    required String signature,
  }) async =>
      keyId == 'archive-test-key' && signature == 'trusted-test-signature';
}

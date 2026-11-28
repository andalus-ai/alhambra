import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_access_audit_chain.dart';
import 'plugin_revocation_access_audit_checkpoint.dart';
import 'plugin_revocation_admin_operations.dart';

/// One immutable audit-chain entry as exported for offline verification.
final class PluginRevocationAccessAuditArchiveEntry {
  final int sequence;
  final String previousHash;
  final String entryHash;
  final PluginRevocationOperationsAccessAudit audit;

  PluginRevocationAccessAuditArchiveEntry({
    required this.sequence,
    required this.previousHash,
    required this.entryHash,
    required this.audit,
  }) {
    if (sequence < 1 ||
        !_isHash(previousHash) ||
        !_isHash(entryHash)) {
      throw ArgumentError('Invalid audit archive entry.');
    }
  }
}

/// Self-contained, digest-protected range of one scope's audit chain.
final class PluginRevocationAccessAuditArchivePackage {
  static const int currentFormatVersion = 1;

  final int formatVersion;
  final String packageId;
  final String scopeId;
  final int fromSequence;
  final int toSequence;
  final String previousHash;
  final String headHash;
  final DateTime createdAt;
  final String checkpointDigest;
  final List<PluginRevocationAccessAuditArchiveEntry> entries;
  final String digestAlgorithm;
  final String digest;

  PluginRevocationAccessAuditArchivePackage({
    this.formatVersion = currentFormatVersion,
    required this.packageId,
    required this.scopeId,
    required this.fromSequence,
    required this.toSequence,
    required this.previousHash,
    required this.headHash,
    required DateTime createdAt,
    required this.checkpointDigest,
    required Iterable<PluginRevocationAccessAuditArchiveEntry> entries,
    this.digestAlgorithm = 'sha256',
    required this.digest,
  }) : createdAt = createdAt.toUtc(),
       entries = List.unmodifiable(entries) {
    if (formatVersion != currentFormatVersion ||
        packageId.trim().isEmpty ||
        scopeId.trim().isEmpty ||
        fromSequence < 1 ||
        toSequence < fromSequence ||
        this.entries.isEmpty ||
        this.entries.length != toSequence - fromSequence + 1 ||
        !_isHash(previousHash) ||
        !_isHash(headHash) ||
        !_isHash(checkpointDigest) ||
        digestAlgorithm != 'sha256' ||
        !_isHash(digest)) {
      throw ArgumentError('Invalid plugin revocation audit archive package.');
    }
  }
}

abstract final class PluginRevocationAccessAuditArchiveCodec {
  static String encodePayload(PluginRevocationAccessAuditArchivePackage value) =>
      jsonEncode({
        'formatVersion': value.formatVersion,
        'packageId': value.packageId,
        'scopeId': value.scopeId,
        'fromSequence': value.fromSequence,
        'toSequence': value.toSequence,
        'previousHash': value.previousHash,
        'headHash': value.headHash,
        'createdAt': value.createdAt.toUtc().toIso8601String(),
        'checkpointDigest': value.checkpointDigest,
        'entries': value.entries.map((entry) => {
          'sequence': entry.sequence,
          'previousHash': entry.previousHash,
          'entryHash': entry.entryHash,
          'audit': _auditToJson(entry.audit),
        }).toList(growable: false),
      });

  static String calculateDigest(PluginRevocationAccessAuditArchivePackage value) =>
      sha256.convert(utf8.encode(encodePayload(value))).toString();

  static PluginRevocationAccessAuditArchiveVerification verify(
    PluginRevocationAccessAuditArchivePackage value,
  ) {
    var previous = value.previousHash;
    var expectedSequence = value.fromSequence;
    for (final entry in value.entries) {
      if (entry.audit.scopeId != value.scopeId ||
          entry.sequence != expectedSequence ||
          entry.previousHash != previous) {
        return PluginRevocationAccessAuditArchiveVerification(
          valid: false,
          verifiedEntries: expectedSequence - value.fromSequence,
          failedSequence: entry.sequence,
          expectedHeadHash: previous,
        );
      }
      final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(
        entry.audit,
      );
      final expectedHash = PluginRevocationAccessAuditChainCodec.hash(
        previousHash: previous,
        canonicalPayload: payload,
      );
      if (entry.entryHash != expectedHash) {
        return PluginRevocationAccessAuditArchiveVerification(
          valid: false,
          verifiedEntries: expectedSequence - value.fromSequence,
          failedSequence: entry.sequence,
          expectedHeadHash: expectedHash,
        );
      }
      previous = entry.entryHash;
      expectedSequence++;
    }
    final actualDigest = calculateDigest(value);
    final valid = previous == value.headHash &&
        expectedSequence - 1 == value.toSequence &&
        actualDigest == value.digest;
    return PluginRevocationAccessAuditArchiveVerification(
      valid: valid,
      verifiedEntries: value.entries.length,
      expectedHeadHash: previous,
      failedSequence: valid ? null : value.toSequence,
    );
  }

  static Map<String, Object?> _auditToJson(
    PluginRevocationOperationsAccessAudit audit,
  ) => {
    'actorId': audit.actorId,
    'scopeId': audit.scopeId,
    'decision': audit.decision.name,
    'denialCode': audit.denialCode,
    'occurredAt': audit.occurredAt.toUtc().toIso8601String(),
    'resource': audit.resource,
    'pageSize': audit.pageSize,
    'continuationRequested': audit.continuationRequested,
    'queryFingerprint': audit.queryFingerprint,
  };
}

final class PluginRevocationAccessAuditArchiveVerification {
  final bool valid;
  final int verifiedEntries;
  final int? failedSequence;
  final String expectedHeadHash;

  const PluginRevocationAccessAuditArchiveVerification({
    required this.valid,
    required this.verifiedEntries,
    required this.expectedHeadHash,
    this.failedSequence,
  });
}

/// Adapter port for exporting a bounded, already-verified contiguous segment.
abstract interface class PluginRevocationAccessAuditArchiveSource {
  Future<List<PluginRevocationAccessAuditArchiveEntry>> readArchiveEntries({
    required String scopeId,
    required int fromSequence,
    required int limit,
  });
}

final class PluginRevocationAccessAuditArchiveExportException
    implements Exception {
  final String message;
  const PluginRevocationAccessAuditArchiveExportException(this.message);

  @override
  String toString() => message;
}

/// Exports only a contiguous segment whose final head is covered by the
/// supplied externally signed checkpoint. The caller must obtain the
/// checkpoint from its trusted checkpoint service and retain it with package.
final class PluginRevocationAccessAuditArchiveExporter {
  final PluginRevocationAccessAuditChainStore chainStore;
  final PluginRevocationAccessAuditArchiveSource source;
  final PluginRevocationAccessAuditCheckpointVerifier checkpointVerifier;
  final DateTime Function() clock;

  PluginRevocationAccessAuditArchiveExporter({
    required this.chainStore,
    required this.source,
    required this.checkpointVerifier,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAccessAuditArchivePackage> export({
    required String packageId,
    required String scopeId,
    required int fromSequence,
    required int limit,
    required PluginRevocationAccessAuditCheckpoint checkpoint,
  }) async {
    if (packageId.trim().isEmpty ||
        scopeId.trim().isEmpty ||
        fromSequence < 1 ||
        limit < 1 ||
        limit > 1000) {
      throw ArgumentError('Invalid audit archive export request.');
    }
    if (checkpoint.scopeId != scopeId ||
        checkpoint.sequence < fromSequence ||
        checkpoint.sequence > fromSequence + limit - 1) {
      throw ArgumentError('Checkpoint anchor does not cover the requested segment.');
    }
    final checkpointPayload =
        PluginRevocationAccessAuditCheckpointCodec.canonicalPayload(
      scopeId: checkpoint.scopeId,
      sequence: checkpoint.sequence,
      headHash: checkpoint.headHash,
      createdAt: checkpoint.createdAt,
      signingKeyId: checkpoint.signingKeyId,
      previousCheckpointDigest: checkpoint.previousCheckpointDigest,
    );
    if (!await checkpointVerifier.verify(
      keyId: checkpoint.signingKeyId,
      canonicalPayload: checkpointPayload,
      signature: checkpoint.signature,
    )) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'The supplied checkpoint signature is invalid.',
      );
    }
    final checkpointDigest =
        PluginRevocationAccessAuditCheckpointCodec.digest(checkpoint);
    final before = await chainStore.verifyAccessAuditChain(scopeId: scopeId);
    if (!before.valid || before.scopeId != scopeId ||
        before.entriesVerified < checkpoint.sequence) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'Cannot export from an invalid or incomplete audit chain.',
      );
    }
    final entries = await source.readArchiveEntries(
      scopeId: scopeId,
      fromSequence: fromSequence,
      limit: limit,
    );
    if (entries.isEmpty || entries.length > limit ||
        entries.first.sequence != fromSequence) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'The archive source returned an empty or non-contiguous segment.',
      );
    }
    final after = await chainStore.verifyAccessAuditChain(scopeId: scopeId);
    if (!after.valid || after.headHash != before.headHash ||
        after.entriesVerified != before.entriesVerified) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'The source chain changed during archive export.',
      );
    }
    final last = entries.last;
    if (last.sequence != checkpoint.sequence || last.entryHash != checkpoint.headHash) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'The exported segment does not terminate at the supplied checkpoint.',
      );
    }
    final provisional = PluginRevocationAccessAuditArchivePackage(
      packageId: packageId,
      scopeId: scopeId,
      fromSequence: fromSequence,
      toSequence: last.sequence,
      previousHash: entries.first.previousHash,
      headHash: last.entryHash,
      createdAt: clock(),
      checkpointDigest: checkpointDigest,
      entries: entries,
      digest: List<String>.filled(64, '0').join(),
    );
    final package = PluginRevocationAccessAuditArchivePackage(
      packageId: provisional.packageId,
      scopeId: provisional.scopeId,
      fromSequence: provisional.fromSequence,
      toSequence: provisional.toSequence,
      previousHash: provisional.previousHash,
      headHash: provisional.headHash,
      createdAt: provisional.createdAt,
      checkpointDigest: provisional.checkpointDigest,
      entries: provisional.entries,
      digest: PluginRevocationAccessAuditArchiveCodec.calculateDigest(provisional),
    );
    final verification = PluginRevocationAccessAuditArchiveCodec.verify(package);
    if (!verification.valid) {
      throw const PluginRevocationAccessAuditArchiveExportException(
        'The exported archive package failed self-verification.',
      );
    }
    return package;
  }
}


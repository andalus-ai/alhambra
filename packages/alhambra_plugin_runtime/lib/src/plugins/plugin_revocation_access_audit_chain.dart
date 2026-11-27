import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_admin_operations.dart';

/// Canonical serialization and hashing rules shared by durable audit adapters.
///
/// The chain hash is SHA-256 over UTF-8 bytes of
/// `previousHash + "\\n" + canonicalPayload`. Each scope has an independent
/// chain beginning with [genesisHash]. The canonical payload is a JSON array
/// with a fixed field order; do not change its order or normalization without
/// introducing a versioned codec.
abstract final class PluginRevocationAccessAuditChainCodec {
  static const String genesisHash = '0' * 64;
  static const int formatVersion = 1;

  static String canonicalPayload(
    PluginRevocationOperationsAccessAudit audit,
  ) {
    return jsonEncode([
      formatVersion,
      audit.actorId,
      audit.scopeId,
      audit.decision.name,
      audit.denialCode,
      audit.occurredAt.toUtc().toIso8601String(),
      audit.resource,
      audit.pageSize,
      audit.continuationRequested,
      audit.queryFingerprint,
    ]);
  }

  static String hash({
    required String previousHash,
    required String canonicalPayload,
  }) =>
      sha256
          .convert(utf8.encode('$previousHash\n$canonicalPayload'))
          .toString();
}

/// Result of verifying one scope's durable audit hash chain.
final class PluginRevocationAccessAuditChainVerification {
  final String scopeId;
  final bool valid;
  final int entriesVerified;
  final int? failedSequence;
  final String? expectedHash;
  final String? actualHash;
  final String headHash;

  const PluginRevocationAccessAuditChainVerification({
    required this.scopeId,
    required this.valid,
    required this.entriesVerified,
    required this.headHash,
    this.failedSequence,
    this.expectedHash,
    this.actualHash,
  });
}

/// Optional tamper-evidence capability for a durable access-audit adapter.
///
/// Implementations verify the stored chain and compare each chain payload
/// with its corresponding audit row. This detects accidental or unauthorized
/// edits to covered records, but a privileged database operator able to rewrite
/// both tables can recompute the chain. External signed checkpoints or
/// immutable archival are required to detect wholesale database rewriting.
abstract interface class PluginRevocationAccessAuditChainStore {
  Future<PluginRevocationAccessAuditChainVerification>
      verifyAccessAuditChain({required String scopeId});
}

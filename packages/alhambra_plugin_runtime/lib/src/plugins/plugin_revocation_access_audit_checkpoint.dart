import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_access_audit_chain.dart';
import 'plugin_revocation_admin_operations.dart';

/// Immutable, externally anchored statement about one scope's audit-chain head.
final class PluginRevocationAccessAuditCheckpoint {
  final int formatVersion;
  final String scopeId;
  final int sequence;
  final String headHash;
  final DateTime createdAt;
  final String signingKeyId;
  final String signature;
  final String? previousCheckpointDigest;

  PluginRevocationAccessAuditCheckpoint({
    this.formatVersion = 1,
    required this.scopeId,
    required this.sequence,
    required this.headHash,
    required this.createdAt,
    required this.signingKeyId,
    required this.signature,
    this.previousCheckpointDigest,
  }) {
    if (formatVersion != 1 ||
        scopeId.trim().isEmpty ||
        sequence < 1 ||
        !_isSha256(headHash) ||
        signingKeyId.trim().isEmpty ||
        signature.trim().isEmpty ||
        (previousCheckpointDigest != null &&
            !_isSha256(previousCheckpointDigest!))) {
      throw ArgumentError('Invalid plugin revocation audit checkpoint.');
    }
  }

  static bool _isSha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

/// Stable, versioned representation covered by the checkpoint signature.
abstract final class PluginRevocationAccessAuditCheckpointCodec {
  static const int formatVersion = 1;

  static String canonicalPayload({
    required String scopeId,
    required int sequence,
    required String headHash,
    required DateTime createdAt,
    required String signingKeyId,
    required String? previousCheckpointDigest,
  }) =>
      jsonEncode([
        formatVersion,
        scopeId,
        sequence,
        headHash,
        createdAt.toUtc().toIso8601String(),
        signingKeyId,
        previousCheckpointDigest ?? '',
      ]);

  static String digest(PluginRevocationAccessAuditCheckpoint checkpoint) {
    final payload = canonicalPayload(
      scopeId: checkpoint.scopeId,
      sequence: checkpoint.sequence,
      headHash: checkpoint.headHash,
      createdAt: checkpoint.createdAt,
      signingKeyId: checkpoint.signingKeyId,
      previousCheckpointDigest: checkpoint.previousCheckpointDigest,
    );
    return sha256
        .convert(utf8.encode('$payload\n${checkpoint.signature}'))
        .toString();
  }
}

/// Signing is supplied by the host (for example, an HSM or cloud KMS adapter).
abstract interface class PluginRevocationAccessAuditCheckpointSigner {
  String get keyId;

  Future<String> sign(String canonicalPayload);
}

/// Verification is supplied by the host and must validate the key ID and
/// signature against the host's current trust policy, including key rotation.
abstract interface class PluginRevocationAccessAuditCheckpointVerifier {
  Future<bool> verify({
    required String keyId,
    required String canonicalPayload,
    required String signature,
  });
}

/// Independently controlled checkpoint history. Implementations should use
/// append-only or immutable storage and enforce the expected previous digest
/// atomically to prevent concurrent writers from forking the history.
abstract interface class PluginRevocationAccessAuditCheckpointStore {
  Future<PluginRevocationAccessAuditCheckpoint?> readLatest({
    required String scopeId,
  });

  Future<bool> append({
    required String? expectedPreviousDigest,
    required PluginRevocationAccessAuditCheckpoint checkpoint,
  });
}

/// Adapter capability that proves an externally anchored head is still present
/// in the verified local chain. This prevents accepting a rewritten chain that
/// merely has a later sequence number.
abstract interface class PluginRevocationAccessAuditCheckpointChainVerifier {
  Future<bool> containsVerifiedHead({
    required String scopeId,
    required int sequence,
    required String headHash,
  });
}

/// Host authorization boundary for checkpoint creation and verification.
abstract interface class PluginRevocationAccessAuditCheckpointAuthorizer {
  Future<bool> canManageAuditCheckpoint({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  });
}

final class PluginRevocationAccessAuditCheckpointUnavailableException
    implements Exception {
  const PluginRevocationAccessAuditCheckpointUnavailableException();
}

final class PluginRevocationAccessAuditCheckpointDeniedException
    implements Exception {
  const PluginRevocationAccessAuditCheckpointDeniedException();
}

final class PluginRevocationAccessAuditCheckpointIntegrityException
    implements Exception {
  final String reason;

  const PluginRevocationAccessAuditCheckpointIntegrityException(this.reason);

  @override
  String toString() => 'Audit checkpoint integrity failure: $reason';
}

/// Creates signed external anchors and validates the latest anchor against the
/// current, fully verified local chain. It deliberately does not write to the
/// audit trail being checkpointed, avoiding recursive self-auditing.
final class PluginRevocationAccessAuditCheckpointService {
  final PluginRevocationAccessAuditChainStore chainStore;
  final PluginRevocationAccessAuditCheckpointChainVerifier chainVerifier;
  final PluginRevocationAccessAuditCheckpointStore checkpointStore;
  final PluginRevocationAccessAuditCheckpointSigner signer;
  final PluginRevocationAccessAuditCheckpointVerifier signatureVerifier;
  final PluginRevocationAccessAuditCheckpointAuthorizer authorizer;
  final DateTime Function() clock;

  PluginRevocationAccessAuditCheckpointService({
    required this.chainStore,
    required this.chainVerifier,
    required this.checkpointStore,
    required this.signer,
    required this.signatureVerifier,
    required this.authorizer,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAccessAuditCheckpoint> createCheckpoint({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    await _authorize(principal, scopeId);
    final verification =
        await chainStore.verifyAccessAuditChain(scopeId: scopeId);
    if (!verification.valid || verification.entriesVerified < 1) {
      throw const PluginRevocationAccessAuditCheckpointIntegrityException(
        'The local audit chain is invalid or empty.',
      );
    }

    final previous = await checkpointStore.readLatest(scopeId: scopeId);
    if (previous != null) {
      await _verifySignature(previous);
      if (previous.sequence > verification.entriesVerified) {
        throw const PluginRevocationAccessAuditCheckpointIntegrityException(
          'The local chain is behind the latest external checkpoint.',
        );
      }
      final contains = await chainVerifier.containsVerifiedHead(
        scopeId: scopeId,
        sequence: previous.sequence,
        headHash: previous.headHash,
      );
      if (!contains) {
        throw const PluginRevocationAccessAuditCheckpointIntegrityException(
          'The latest external checkpoint is not present in the local chain.',
        );
      }
      if (previous.sequence == verification.entriesVerified &&
          previous.headHash != verification.headHash) {
        throw const PluginRevocationAccessAuditCheckpointIntegrityException(
          'The local chain head conflicts with the external checkpoint.',
        );
      }
    }

    final now = clock().toUtc();
    final keyId = signer.keyId;
    if (keyId.trim().isEmpty) {
      throw const PluginRevocationAccessAuditCheckpointUnavailableException();
    }
    final payload = PluginRevocationAccessAuditCheckpointCodec.canonicalPayload(
      scopeId: scopeId,
      sequence: verification.entriesVerified,
      headHash: verification.headHash,
      createdAt: now,
      signingKeyId: keyId,
      previousCheckpointDigest: previous == null
          ? null
          : PluginRevocationAccessAuditCheckpointCodec.digest(previous),
    );
    final signature = await signer.sign(payload);
    final checkpoint = PluginRevocationAccessAuditCheckpoint(
      scopeId: scopeId,
      sequence: verification.entriesVerified,
      headHash: verification.headHash,
      createdAt: now,
      signingKeyId: keyId,
      signature: signature,
      previousCheckpointDigest: previous == null
          ? null
          : PluginRevocationAccessAuditCheckpointCodec.digest(previous),
    );
    final appended = await checkpointStore.append(
      expectedPreviousDigest: previous == null
          ? null
          : PluginRevocationAccessAuditCheckpointCodec.digest(previous),
      checkpoint: checkpoint,
    );
    if (!appended) {
      throw const PluginRevocationAccessAuditCheckpointIntegrityException(
        'Checkpoint history changed concurrently; retry after re-reading it.',
      );
    }
    return checkpoint;
  }

  Future<PluginRevocationAccessAuditCheckpoint> verifyLatest({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    await _authorize(principal, scopeId);
    final checkpoint = await checkpointStore.readLatest(scopeId: scopeId);
    if (checkpoint == null) {
      throw const PluginRevocationAccessAuditCheckpointUnavailableException();
    }
    await _verifySignature(checkpoint);
    final chain = await chainStore.verifyAccessAuditChain(scopeId: scopeId);
    if (!chain.valid || chain.entriesVerified < checkpoint.sequence) {
      throw const PluginRevocationAccessAuditCheckpointIntegrityException(
        'The local chain is invalid or has rolled back behind its anchor.',
      );
    }
    final contains = await chainVerifier.containsVerifiedHead(
      scopeId: scopeId,
      sequence: checkpoint.sequence,
      headHash: checkpoint.headHash,
    );
    if (!contains) {
      throw const PluginRevocationAccessAuditCheckpointIntegrityException(
        'The anchored checkpoint is absent from the verified local chain.',
      );
    }
    return checkpoint;
  }

  Future<void> _authorize(
    PluginRevocationOperationsPrincipal principal,
    String scopeId,
  ) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    if (!await authorizer.canManageAuditCheckpoint(
      principal: principal,
      scopeId: scopeId,
    )) {
      throw const PluginRevocationAccessAuditCheckpointDeniedException();
    }
  }

  Future<void> _verifySignature(
    PluginRevocationAccessAuditCheckpoint checkpoint,
  ) async {
    final payload = PluginRevocationAccessAuditCheckpointCodec.canonicalPayload(
      scopeId: checkpoint.scopeId,
      sequence: checkpoint.sequence,
      headHash: checkpoint.headHash,
      createdAt: checkpoint.createdAt,
      signingKeyId: checkpoint.signingKeyId,
      previousCheckpointDigest: checkpoint.previousCheckpointDigest,
    );
    if (!await signatureVerifier.verify(
      keyId: checkpoint.signingKeyId,
      canonicalPayload: payload,
      signature: checkpoint.signature,
    )) {
      throw const PluginRevocationAccessAuditCheckpointIntegrityException(
        'The external checkpoint signature is invalid.',
      );
    }
  }
}

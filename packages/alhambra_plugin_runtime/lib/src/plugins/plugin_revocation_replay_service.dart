import 'plugin_revocation_operator_actions.dart';

/// Authenticated identity supplied by the embedding host.
///
/// The runtime does not parse JWTs or infer tenancy. [scopeId] is an opaque
/// tenant/workspace/security-boundary identifier assigned by the host.
final class PluginRevocationReplayPrincipal {
  final String actorId;
  final String scopeId;

  PluginRevocationReplayPrincipal({
    required this.actorId,
    required this.scopeId,
  }) {
    if (actorId.trim().isEmpty || scopeId.trim().isEmpty) {
      throw ArgumentError('Replay principal actorId and scopeId are required.');
    }
  }
}

/// Resolves the authoritative scope of a persisted outbox event.
///
/// Implementations should use the host's authoritative tenant/resource
/// mapping, not caller-supplied metadata.
abstract interface class PluginRevocationReplayScopeResolver {
  Future<String?> resolveScopeId(String eventId);
}

/// Host authorization adapter, e.g. OPA, Keycloak-backed policy, or RBAC.
abstract interface class PluginRevocationReplayAuthorizer {
  Future<bool> canReplay({
    required PluginRevocationReplayPrincipal principal,
    required String targetEventId,
  });
}

/// Verifies durable approval evidence using the host's change/approval system.
abstract interface class PluginRevocationReplayApprovalVerifier {
  Future<bool> isApproved({
    required PluginRevocationReplayPrincipal principal,
    required String targetEventId,
    required String approvalReference,
  });
}

enum PluginRevocationReplayDenialReason {
  scopeMismatch,
  permissionDenied,
  approvalRejected,
}

/// Raised before persistence is invoked when host authorization fails.
final class PluginRevocationReplayDeniedException implements Exception {
  final PluginRevocationReplayDenialReason reason;

  const PluginRevocationReplayDeniedException(this.reason);

  @override
  String toString() => 'Plugin revocation replay denied: ${reason.name}.';
}

/// Security boundary that authorizes an operator before invoking replay
/// persistence. It deliberately has no HTTP, JWT, database, or tenant-provider
/// dependency; the host supplies identity, scope, authorization and approval
/// adapters.
final class PluginRevocationReplayCommandService {
  final PluginRevocationDeadLetterReplayStore store;
  final PluginRevocationReplayScopeResolver scopeResolver;
  final PluginRevocationReplayAuthorizer authorizer;
  final PluginRevocationReplayApprovalVerifier approvalVerifier;
  final DateTime Function() clock;

  PluginRevocationReplayCommandService({
    required this.store,
    required this.scopeResolver,
    required this.authorizer,
    required this.approvalVerifier,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationReplayResult?> replay({
    required String actionId,
    required PluginRevocationReplayPrincipal principal,
    required String targetEventId,
    required String reason,
    required String approvalReference,
    DateTime? occurredAt,
  }) async {
    final request = PluginRevocationReplayRequest(
      actionId: actionId,
      actorId: principal.actorId,
      scopeId: principal.scopeId,
      reason: reason,
      approvalReference: approvalReference,
      targetEventId: targetEventId,
      occurredAt: (occurredAt ?? clock()).toUtc(),
    );

    final targetScope = await scopeResolver.resolveScopeId(targetEventId);
    if (targetScope == null || targetScope != principal.scopeId) {
      throw const PluginRevocationReplayDeniedException(
        PluginRevocationReplayDenialReason.scopeMismatch,
      );
    }

    if (!await authorizer.canReplay(
      principal: principal,
      targetEventId: targetEventId,
    )) {
      throw const PluginRevocationReplayDeniedException(
        PluginRevocationReplayDenialReason.permissionDenied,
      );
    }

    if (!await approvalVerifier.isApproved(
      principal: principal,
      targetEventId: targetEventId,
      approvalReference: approvalReference,
    )) {
      throw const PluginRevocationReplayDeniedException(
        PluginRevocationReplayDenialReason.approvalRejected,
      );
    }

    return store.replayDeadLetter(request);
  }
}

import 'plugin_revocation_outbox.dart';

/// A host-authorized operator action persisted with the replay it authorizes.
///
/// [actorId] is supplied by the host's authenticated identity layer. The
/// runtime does not authenticate operators or interpret approval references.
final class PluginRevocationOperatorAction {
  final String actionId;
  final String actorId;
  /// Opaque host-defined tenant or security boundary identifier.
  final String scopeId;
  final String reason;
  final String approvalReference;
  final String targetEventId;
  final String replayEventId;
  final int replayGeneration;
  final DateTime occurredAt;

  PluginRevocationOperatorAction({
    required this.actionId,
    required this.actorId,
    this.scopeId = 'default',
    required this.reason,
    required this.approvalReference,
    required this.targetEventId,
    required this.replayEventId,
    required this.replayGeneration,
    required this.occurredAt,
  }) {
    for (final value in [
      actionId,
      actorId,
      scopeId,
      reason,
      approvalReference,
      targetEventId,
      replayEventId,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('Operator replay audit fields must not be empty.');
      }
    }
    if (replayGeneration < 1) {
      throw ArgumentError.value(replayGeneration, 'replayGeneration');
    }
  }
}

/// Explicit replay command. The caller must authorize the actor and provide
/// durable approval evidence before invoking the store.
final class PluginRevocationReplayRequest {
  final String actionId;
  final String actorId;
  /// Opaque host-defined tenant or security boundary identifier.
  final String scopeId;
  final String reason;
  final String approvalReference;
  final String targetEventId;
  final DateTime occurredAt;

  PluginRevocationReplayRequest({
    required this.actionId,
    required this.actorId,
    this.scopeId = 'default',
    required this.reason,
    required this.approvalReference,
    required this.targetEventId,
    required this.occurredAt,
  }) {
    for (final value in [
      actionId,
      actorId,
      scopeId,
      reason,
      approvalReference,
      targetEventId,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('Replay request fields must not be empty.');
      }
    }
  }
}

final class PluginRevocationReplayResult {
  final PluginRevocationOperatorAction audit;
  final PluginRevocationOutboxMessage replay;

  const PluginRevocationReplayResult(this.audit, this.replay);
}

/// Atomic operator-audit + dead-letter replay persistence boundary.
///
/// Implementations must commit the operator action and newly identified
/// pending outbox message in one transaction. They must reject non-dead-letter
/// sources, preserve the original event, allocate a monotonically increasing
/// replay generation per source event, and make actionId idempotent.
/// They must never reset the original row or reuse its event/idempotency key.
abstract interface class PluginRevocationDeadLetterReplayStore {
  Future<PluginRevocationReplayResult?> replayDeadLetter(
    PluginRevocationReplayRequest request,
  );
}


/// Read-only access to durable operator replay history.
abstract interface class PluginRevocationOperatorActionInspectionStore {
  Future<List<PluginRevocationOperatorAction>> readOperatorActions();
}

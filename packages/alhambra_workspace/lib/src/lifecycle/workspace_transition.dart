import 'package:alhambra_core/alhambra_core.dart';

import 'workspace_status.dart';

/// A recorded state transition on a [Workspace].
///
/// Transitions are explicit value objects so that audit logs, domain events,
/// and versioning can all derive from a single source of truth.
///
/// Example:
/// ```text
/// WorkspaceTransition
///   from: draft
///   to:   review
///   actor: user-123
///   reason: "Submitted for review"
/// ```
final class WorkspaceTransition {
  final WorkspaceId workspaceId;
  final WorkspaceStatus from;
  final WorkspaceStatus to;
  final UserId actorId;
  final DateTime timestamp;
  final String? reason;
  final Map<String, Object?> metadata;

  const WorkspaceTransition({
    required this.workspaceId,
    required this.from,
    required this.to,
    required this.actorId,
    required this.timestamp,
    this.reason,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'WorkspaceTransition($from → $to, actor: $actorId, workspace: $workspaceId)';
}

/// Thrown when a state transition violates the workspace lifecycle rules.
final class WorkspaceTransitionException implements Exception {
  final WorkspaceStatus from;
  final WorkspaceStatus to;

  const WorkspaceTransitionException(this.from, this.to);

  @override
  String toString() =>
      'WorkspaceTransitionException: cannot transition from $from to $to';
}

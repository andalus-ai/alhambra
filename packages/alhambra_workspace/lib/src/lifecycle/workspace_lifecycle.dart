import 'workspace_status.dart';
import 'workspace_transition.dart';

/// Encodes the valid state transitions for an Alhambra [Workspace].
///
/// This is a pure domain object with no side effects — it only evaluates
/// whether a transition is permitted given the current and target status.
///
/// Allowed transitions:
/// ```text
/// draft     → review | archived
/// review    → approved | draft
/// approved  → published | draft
/// published → superseded | archived
/// superseded → archived
/// archived  → (none)
/// ```
final class WorkspaceLifecycle {
  const WorkspaceLifecycle();

  /// Returns `true` if transitioning [from] → [to] is valid.
  bool canTransition(WorkspaceStatus from, WorkspaceStatus to) {
    return switch (from) {
      WorkspaceStatus.draft =>
        to == WorkspaceStatus.review || to == WorkspaceStatus.archived,

      WorkspaceStatus.review =>
        to == WorkspaceStatus.approved || to == WorkspaceStatus.draft,

      WorkspaceStatus.approved =>
        to == WorkspaceStatus.published || to == WorkspaceStatus.draft,

      WorkspaceStatus.published =>
        to == WorkspaceStatus.superseded || to == WorkspaceStatus.archived,

      WorkspaceStatus.superseded => to == WorkspaceStatus.archived,

      WorkspaceStatus.archived => false,
    };
  }

  /// Validates the transition and throws [WorkspaceTransitionException] if invalid.
  void requireTransition(WorkspaceStatus from, WorkspaceStatus to) {
    if (!canTransition(from, to)) {
      throw WorkspaceTransitionException(from, to);
    }
  }
}

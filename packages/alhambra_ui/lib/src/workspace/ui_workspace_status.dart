/// Lifecycle labels rendered by Alhambra's workspace presentation widgets.
///
/// These are UI states, not a domain lifecycle state machine. Applications
/// should map their domain workspace status to this presentation enum.
enum UiWorkspaceStatus {
  draft,
  review,
  approved,
  published,
  superseded,
  archived,
}

/// The lifecycle states of an Alhambra [Workspace].
///
/// State machine:
/// ```text
/// DRAFT ──► REVIEW ──► APPROVED ──► PUBLISHED ──► SUPERSEDED
///   │          │           │             │               │
///   │          └──► DRAFT  └──► DRAFT    └──► ARCHIVED   └──► ARCHIVED
///   │
///   └──► ARCHIVED
/// ```
/// `archived` is a terminal state — no transitions out.
enum WorkspaceStatus {
  /// Initial editable state. Only draft workspaces may be modified.
  draft,

  /// Submitted and awaiting reviewer decision.
  review,

  /// Approved by reviewer; ready for publication.
  approved,

  /// Publicly released. Immutable.
  published,

  /// Replaced by a newer published version.
  superseded,

  /// Terminal state. No further transitions permitted.
  archived,
}

/// Generic lifecycle states for resources across the Alhambra platform.
///
/// Specialized entities (such as Workspaces or Analysis runs) can define richer
/// state transitions while mapping into these fundamental lifecycle categories.
enum LifecycleState {
  /// The resource is being created or configured.
  draft,

  /// The resource is active, operational, and accessible.
  active,

  /// The resource is paused, disabled, or temporarily unavailable.
  inactive,

  /// The resource has been archived and is read-only.
  archived,

  /// The resource has been soft-deleted or marked for purge.
  deleted,
}

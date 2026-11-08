/// P12 sync status — both aggregate engine state and per-operation state.
library;

/// Overall sync engine lifecycle state (stream-based UI observable).
enum SyncStatus {
  /// No pending operations, engine is at rest.
  idle,

  /// Actively dispatching queued operations.
  syncing,

  /// Last synchronization run encountered failures.
  error,

  /// Connectivity is unavailable — queuing only, no dispatch.
  offline,

  /// Engine is paused awaiting re-authentication.
  authRequired,
}

/// State of a single resource's local record.
enum SyncRecordState {
  /// Matches the last known server state.
  synced,

  /// Has local changes not yet confirmed by the server.
  pendingSync,

  /// Has a version conflict with the server.
  conflict,

  /// Locally marked for deletion, awaiting server confirmation.
  pendingDelete,
}

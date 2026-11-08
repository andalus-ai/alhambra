/// The four-dimensional view state model for Alhambra UI screens.
///
/// Each dimension is independent and must never be collapsed into one enum:
///
/// ```
/// DATA          SYNC          AUTHORIZATION   CONNECTIVITY
///  │             │                 │               │
/// loading      synced           allowed          online
/// ready        pending          denied           offline
/// failed       conflict
/// ```
///
/// A screen may simultaneously be:
/// ```
/// data=ready, sync=pending, authorization=allowed, connectivity=offline
/// → "Draft changes saved locally — waiting for connection"
/// ```
library;

// ── Data Dimension ─────────────────────────────────────────────────────────

/// Data fetch state for any async resource.
sealed class ViewState<T> {
  const ViewState();

  /// True when in [Loading] state.
  bool get isLoading => this is Loading<T>;

  /// True when in [Ready] state.
  bool get isReady => this is Ready<T>;

  /// True when in [Failed] state.
  bool get isFailed => this is Failed<T>;

  /// Returns [Ready.data] or `null`.
  T? get dataOrNull => switch (this) {
        Ready<T>(:final data) => data,
        _ => null,
      };

  /// Maps state to a widget builder result.
  R when<R>({
    required R Function() loading,
    required R Function(T data) ready,
    required R Function(Object error) failed,
  }) =>
      switch (this) {
        Loading<T>() => loading(),
        Ready<T>(:final data) => ready(data),
        Failed<T>(:final error) => failed(error),
      };
}

/// Data is being fetched.
final class Loading<T> extends ViewState<T> {
  const Loading();
}

/// Data is available.
final class Ready<T> extends ViewState<T> {
  final T data;
  const Ready(this.data);
}

/// Data fetch failed.
final class Failed<T> extends ViewState<T> {
  final Object error;
  const Failed(this.error);
}

// ── Sync Dimension ──────────────────────────────────────────────────────────

/// Synchronisation state for a resource or the global queue.
enum UiSyncState {
  /// Data is in sync with the server.
  synced,

  /// Local change is queued, not yet sent.
  pending,

  /// Sync in progress.
  syncing,

  /// Sync succeeded but UI hasn't refreshed yet.
  refreshing,

  /// Server rejected with a conflict.
  conflict,

  /// Token expired — retry blocked until re-auth.
  authRequired,
}

/// Human-readable label for a sync state.
extension UiSyncStateLabel on UiSyncState {
  String get label => switch (this) {
        UiSyncState.synced => 'Synced',
        UiSyncState.pending => 'Saved locally',
        UiSyncState.syncing => 'Saving…',
        UiSyncState.refreshing => 'Refreshing…',
        UiSyncState.conflict => 'Sync conflict',
        UiSyncState.authRequired => 'Sign in required',
      };
}

// ── Authorization Dimension ─────────────────────────────────────────────────

/// Presentation-level authorization state.
///
/// NOTE: This is UI-only. Backend authorization remains authoritative.
enum UiAuthState {
  /// User has the required permission (UI may proceed).
  allowed,

  /// User lacks permission (UI hides or disables).
  denied,
}

// ── Connectivity Dimension ──────────────────────────────────────────────────

/// Device network connectivity state, as observed by the UI layer.
enum UiConnectivityState {
  /// Network reachable.
  online,

  /// No network. Mutations are queued locally.
  offline,
}

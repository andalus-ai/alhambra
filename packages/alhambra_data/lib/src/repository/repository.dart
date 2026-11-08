/// P12 standard repository abstraction.
///
/// Provides consistent data-access semantics regardless of whether the
/// underlying source is local cache, local DB, or remote API.
abstract interface class Repository<T, ID> {
  /// Returns the entity with [id], or `null` if not found.
  Future<T?> get(ID id);

  /// Lists all entities.
  Future<List<T>> list();

  /// Saves (inserts or updates) [entity] and returns the persisted form.
  Future<T> save(T entity);

  /// Deletes the entity with [id].
  Future<void> delete(ID id);
}

/// Extends [Repository] with sync capabilities for local-first clients.
abstract interface class SyncRepository<T, ID> implements Repository<T, ID> {
  /// Synchronizes this repository with the remote backend.
  Future<SyncState> sync();

  /// Returns a stream of sync state changes for this repository.
  Stream<SyncState> watchSync();

  /// Forces a refresh of the entity with [id] from the remote.
  Future<void> refresh(ID id);

  /// Forces a refresh of all entities from the remote.
  Future<void> refreshAll();
}

/// Observable state of a repository's synchronization.
enum SyncState {
  /// Local and remote are in sync.
  synced,

  /// Currently communicating with the remote.
  syncing,

  /// Has unconfirmed local mutations.
  pendingSync,

  /// Cannot sync — no connectivity.
  offline,

  /// Last sync attempt produced an error.
  error,
}

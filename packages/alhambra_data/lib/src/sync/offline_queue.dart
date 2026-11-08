import 'sync_operation.dart';

/// Contract for persistent offline mutation queue.
abstract interface class OfflineQueue {
  /// Enqueues a sync operation. Deduplicates by [SyncOperation.id].
  Future<void> enqueue(SyncOperation operation);

  /// Returns chronological list of all pending operations
  /// (status == [SyncOperationStatus.pending] or [SyncOperationStatus.retrying]).
  Future<List<SyncOperation>> pending();

  /// Updates the status (and attempt metadata) of an existing operation.
  Future<void> updateStatus(SyncOperation operation);

  /// Removes a completed or discarded operation by [operationId].
  Future<void> remove(String operationId);

  /// Clears all queued operations.
  Future<void> clear();

  /// Total count of pending operations.
  Future<int> count();
}

/// In-memory implementation of [OfflineQueue] for testing and in-process use.
final class InMemoryOfflineQueue implements OfflineQueue {
  final Map<String, SyncOperation> _store = {};

  @override
  Future<void> enqueue(SyncOperation operation) async {
    _store.putIfAbsent(operation.id, () => operation);
  }

  @override
  Future<List<SyncOperation>> pending() async => _store.values
      .where((op) =>
          op.status == SyncOperationStatus.pending ||
          op.status == SyncOperationStatus.retrying)
      .toList();

  @override
  Future<void> updateStatus(SyncOperation operation) async {
    if (_store.containsKey(operation.id)) {
      _store[operation.id] = operation;
    }
  }

  @override
  Future<void> remove(String operationId) async {
    _store.remove(operationId);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<int> count() async => _store.length;
}

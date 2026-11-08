import 'package:alhambra_data/alhambra_data.dart'
    show OfflineQueue, SyncOperation, SyncOperationStatus;
import 'package:sembast/sembast.dart' as sembast;

/// Sembast implementation of [OfflineQueue].
///
/// Operations are stored in a [sembast.StoreRef] named `'offline_queue'`,
/// keyed by [SyncOperation.id]. [pending] filters for
/// [SyncOperationStatus.pending] and [SyncOperationStatus.retrying] only.
/// Enqueue deduplicates by id.
class SembastOfflineQueue implements OfflineQueue {
  SembastOfflineQueue(this._db);

  final sembast.Database _db;

  static const _storeName = 'offline_queue';
  final sembast.StoreRef<String, Map<String, Object?>> _store =
      sembast.StoreRef<String, Map<String, Object?>>(_storeName);

  // ── helpers ──────────────────────────────────────────────────────────────

  Map<String, Object?> _toMap(SyncOperation op) => {
        'id': op.id,
        'idempotencyKey': op.idempotencyKey,
        'resourceType': op.resourceType,
        'resourceId': op.resourceId,
        'operation': op.operation,
        'organizationId': op.organizationId,
        'baseVersion': op.baseVersion,
        'createdAt': op.createdAt.toIso8601String(),
        'attemptCount': op.attemptCount,
        'lastAttemptAt': op.lastAttemptAt?.toIso8601String(),
        'status': op.status.name,
        'payload': op.payload,
      };

  SyncOperation _fromMap(Map<String, Object?> m) => SyncOperation(
        id: m['id'] as String,
        idempotencyKey: m['idempotencyKey'] as String,
        resourceType: m['resourceType'] as String,
        resourceId: m['resourceId'] as String,
        operation: m['operation'] as String,
        organizationId: m['organizationId'] as String?,
        baseVersion: m['baseVersion'] as int?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        attemptCount: m['attemptCount'] as int? ?? 0,
        lastAttemptAt: m['lastAttemptAt'] != null
            ? DateTime.parse(m['lastAttemptAt'] as String)
            : null,
        status: SyncOperationStatus.values
            .firstWhere((s) => s.name == m['status'] as String),
        payload: (m['payload'] as Map?)?.cast<String, Object?>() ?? {},
      );

  // ── OfflineQueue ──────────────────────────────────────────────────────────

  @override
  Future<void> enqueue(SyncOperation operation) async {
    final record = _store.record(operation.id);
    // deduplication: only write if not already present
    if (await record.get(_db) == null) {
      await record.put(_db, _toMap(operation));
    }
  }

  @override
  Future<List<SyncOperation>> pending() async {
    final snapshots = await _store.find(_db);
    return snapshots
        .map((s) => _fromMap(s.value))
        .where((op) =>
            op.status == SyncOperationStatus.pending ||
            op.status == SyncOperationStatus.retrying)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> updateStatus(SyncOperation operation) async {
    final record = _store.record(operation.id);
    if (await record.get(_db) != null) {
      await record.put(_db, _toMap(operation));
    }
  }

  @override
  Future<void> remove(String operationId) =>
      _store.record(operationId).delete(_db);

  @override
  Future<void> clear() => _store.delete(_db);

  @override
  Future<int> count() async => _store.count(_db);
}

import 'package:alhambra_data/alhambra_data.dart'
    show LocalRecord, SyncRecordState;
import 'package:sembast/sembast.dart' as sembast;

/// Sembast-backed persistent store for [LocalRecord]s.
///
/// Keys follow the pattern `'$orgId/$resourceType/$resourceId'` to enforce
/// tenant isolation. Uses a [sembast.StoreRef] named `'local_records'`.
class SembastLocalRecordStore {
  SembastLocalRecordStore(this._db);

  final sembast.Database _db;

  static const _storeName = 'local_records';
  final sembast.StoreRef<String, Map<String, Object?>> _store =
      sembast.StoreRef<String, Map<String, Object?>>(_storeName);

  // ── helpers ──────────────────────────────────────────────────────────────

  String _key(String? orgId, String resourceType, String resourceId) =>
      '${orgId ?? '_'}/$resourceType/$resourceId';

  Map<String, Object?> _toMap(LocalRecord r) => {
        'resourceType': r.resourceType,
        'resourceId': r.resourceId,
        'organizationId': r.organizationId,
        'version': r.version,
        'etag': r.etag,
        'updatedAt': r.updatedAt.toIso8601String(),
        'serverUpdatedAt': r.serverUpdatedAt?.toIso8601String(),
        'state': r.state.name,
        'deleted': r.deleted,
        'payload': r.payload,
      };

  LocalRecord _fromMap(Map<String, Object?> m) => LocalRecord(
        resourceType: m['resourceType'] as String,
        resourceId: m['resourceId'] as String,
        organizationId: m['organizationId'] as String?,
        version: m['version'] as int?,
        etag: m['etag'] as String?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
        serverUpdatedAt: m['serverUpdatedAt'] != null
            ? DateTime.parse(m['serverUpdatedAt'] as String)
            : null,
        state: SyncRecordState.values
            .firstWhere((s) => s.name == m['state'] as String),
        deleted: m['deleted'] as bool? ?? false,
        payload: (m['payload'] as Map?)?.cast<String, Object?>() ?? {},
      );

  // ── public API ────────────────────────────────────────────────────────────

  /// Saves (inserts or replaces) a [record].
  Future<void> save(LocalRecord record) => _store
      .record(_key(record.organizationId, record.resourceType, record.resourceId))
      .put(_db, _toMap(record));

  /// Retrieves the record for the given tenant + resource, or `null`.
  Future<LocalRecord?> get({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) async {
    final raw = await _store
        .record(_key(organizationId, resourceType, resourceId))
        .get(_db);
    return raw == null ? null : _fromMap(raw);
  }

  /// Lists all non-deleted records for [organizationId].
  Future<List<LocalRecord>> listForOrg(String organizationId) async {
    final snapshots = await _store.find(_db);
    return snapshots
        .map((s) => _fromMap(s.value))
        .where((r) => r.organizationId == organizationId && !r.deleted)
        .toList();
  }

  /// Lists all records with [SyncRecordState.pendingSync] across all orgs.
  Future<List<LocalRecord>> get pendingSyncRecords async {
    final snapshots = await _store.find(_db);
    return snapshots
        .map((s) => _fromMap(s.value))
        .where((r) => r.state == SyncRecordState.pendingSync)
        .toList();
  }

  /// Permanently removes a record (after confirmed server delete).
  Future<void> purge({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) =>
      _store
          .record(_key(organizationId, resourceType, resourceId))
          .delete(_db);

  /// Total count of stored records.
  Future<int> get count => _store.count(_db);
}

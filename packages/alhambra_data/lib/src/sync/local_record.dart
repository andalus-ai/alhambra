import 'package:meta/meta.dart';

import 'sync_status.dart';

/// A generic local persistence record wrapping any domain payload.
///
/// Synchronization metadata is kept **separate** from domain semantics —
/// the payload is opaque at this layer.
///
/// Every tenant-owned record carries [organizationId] to prevent cross-tenant
/// data leakage inside the local database.
@immutable
final class LocalRecord {
  /// Domain resource type (e.g. `'workspace'`, `'artifact'`).
  final String resourceType;

  /// Domain resource identifier.
  final String resourceId;

  /// Tenant context — all queries must filter on this when present.
  final String? organizationId;

  /// Optimistic concurrency version from the server, or `null` if unknown.
  final int? version;

  /// ETag from the server, used for `If-Match` request headers.
  final String? etag;

  /// When this local record was last written (local clock).
  final DateTime updatedAt;

  /// When the server last confirmed this record (server clock).
  final DateTime? serverUpdatedAt;

  /// Current sync state of this record.
  final SyncRecordState state;

  /// Soft-delete tombstone flag — `true` means delete is queued but
  /// not yet confirmed by the server.
  final bool deleted;

  /// Opaque domain payload stored as a map.
  final Map<String, Object?> payload;

  const LocalRecord({
    required this.resourceType,
    required this.resourceId,
    required this.updatedAt,
    required this.payload,
    this.organizationId,
    this.version,
    this.etag,
    this.serverUpdatedAt,
    this.state = SyncRecordState.synced,
    this.deleted = false,
  });

  /// Returns a copy with the given fields replaced.
  LocalRecord copyWith({
    int? version,
    String? etag,
    DateTime? updatedAt,
    DateTime? serverUpdatedAt,
    SyncRecordState? state,
    bool? deleted,
    Map<String, Object?>? payload,
  }) =>
      LocalRecord(
        resourceType: resourceType,
        resourceId: resourceId,
        organizationId: organizationId,
        version: version ?? this.version,
        etag: etag ?? this.etag,
        updatedAt: updatedAt ?? this.updatedAt,
        serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
        state: state ?? this.state,
        deleted: deleted ?? this.deleted,
        payload: payload ?? this.payload,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalRecord &&
          resourceType == other.resourceType &&
          resourceId == other.resourceId &&
          organizationId == other.organizationId;

  @override
  int get hashCode => Object.hash(resourceType, resourceId, organizationId);

  @override
  String toString() =>
      'LocalRecord($resourceType/$resourceId, org: $organizationId, '
      'v: $version, state: $state, deleted: $deleted)';
}

/// In-memory store for [LocalRecord]s — for testing and in-process use.
///
/// Keys are `'$organizationId/$resourceType/$resourceId'` to enforce
/// tenant isolation.
final class InMemoryLocalRecordStore {
  final Map<String, LocalRecord> _store = {};

  String _key(String? orgId, String resourceType, String resourceId) =>
      '${orgId ?? '_'}/$resourceType/$resourceId';

  /// Saves (inserts or updates) a [record].
  void save(LocalRecord record) {
    _store[_key(record.organizationId, record.resourceType, record.resourceId)] =
        record;
  }

  /// Retrieves the record for the given tenant + resource, or `null`.
  LocalRecord? get({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) =>
      _store[_key(organizationId, resourceType, resourceId)];

  /// Lists all non-deleted records for an organization.
  List<LocalRecord> listForOrg(String organizationId) => _store.values
      .where((r) => r.organizationId == organizationId && !r.deleted)
      .toList();

  /// Lists all pending-sync records across all orgs.
  List<LocalRecord> get pendingSyncRecords => _store.values
      .where((r) => r.state == SyncRecordState.pendingSync)
      .toList();

  /// Deletes a record permanently from the local store (after confirmed server delete).
  void purge({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) =>
      _store.remove(_key(organizationId, resourceType, resourceId));

  /// Total record count.
  int get count => _store.length;
}

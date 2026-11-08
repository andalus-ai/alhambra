import 'dart:convert';

import 'package:alhambra_data/alhambra_data.dart';

import 'sqlite3_database.dart';

const _kTable = 'local_records';

/// SQLite-backed local record store.
///
/// Mirrors the API of [InMemoryLocalRecordStore] from `alhambra_data` but
/// persists records across restarts. Organisation ID defaults to `'_'` for
/// context-free records.
///
/// Table composite primary key: `(org_id, resource_type, resource_id)`.
final class Sqlite3LocalRecordStore {
  final Sqlite3Database _db;

  Sqlite3LocalRecordStore(this._db);

  /// Creates the backing table if it does not exist.
  Future<void> init() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_kTable (
        org_id          TEXT NOT NULL,
        resource_type   TEXT NOT NULL,
        resource_id     TEXT NOT NULL,
        version         INTEGER,
        etag            TEXT,
        updated_at      TEXT NOT NULL,
        server_updated_at TEXT,
        state           TEXT NOT NULL DEFAULT 'synced',
        deleted         INTEGER NOT NULL DEFAULT 0,
        payload         TEXT,
        PRIMARY KEY (org_id, resource_type, resource_id)
      )
    ''');
  }

  Future<void> save(LocalRecord record) async {
    final orgId = record.organizationId ?? '_';
    await _db.execute(
      '''
      INSERT OR REPLACE INTO $_kTable
        (org_id, resource_type, resource_id, version, etag,
         updated_at, server_updated_at, state, deleted, payload)
      VALUES
        (:org, :rt, :ri, :v, :etag, :ua, :sua, :st, :del, :pl)
      ''',
      parameters: {
        'org': orgId,
        'rt': record.resourceType,
        'ri': record.resourceId,
        'v': record.version,
        'etag': record.etag,
        'ua': record.updatedAt.toIso8601String(),
        'sua': record.serverUpdatedAt?.toIso8601String(),
        'st': record.state.name,
        'del': record.deleted ? 1 : 0,
        'pl': record.payload.isNotEmpty ? jsonEncode(record.payload) : null,
      },
    );
  }

  Future<LocalRecord?> get({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) async {
    final orgId = organizationId ?? '_';
    final rows = await _db.query(
      'SELECT * FROM $_kTable WHERE org_id = :org AND resource_type = :rt AND resource_id = :ri',
      parameters: {'org': orgId, 'rt': resourceType, 'ri': resourceId},
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<LocalRecord>> listForOrg(String organizationId) async {
    final rows = await _db.query(
      'SELECT * FROM $_kTable WHERE org_id = :org AND deleted = 0',
      parameters: {'org': organizationId},
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<LocalRecord>> get pendingSyncRecords async {
    final rows = await _db.query(
      "SELECT * FROM $_kTable WHERE state = 'pendingSync'",
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> purge({
    required String resourceType,
    required String resourceId,
    String? organizationId,
  }) async {
    final orgId = organizationId ?? '_';
    await _db.execute(
      'DELETE FROM $_kTable WHERE org_id = :org AND resource_type = :rt AND resource_id = :ri',
      parameters: {'org': orgId, 'rt': resourceType, 'ri': resourceId},
    );
  }

  Future<int> get count async {
    final rows = await _db.query('SELECT COUNT(*) as n FROM $_kTable');
    return (rows.first['n'] as int?) ?? 0;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  static LocalRecord _fromRow(Map<String, Object?> row) {
    final payloadStr = row['payload'] as String?;
    final payload = payloadStr != null
        ? (jsonDecode(payloadStr) as Map).cast<String, Object?>()
        : <String, Object?>{};
    final suaStr = row['server_updated_at'] as String?;

    final orgId = row['org_id'] as String;
    return LocalRecord(
      resourceType: row['resource_type'] as String,
      resourceId: row['resource_id'] as String,
      organizationId: orgId == '_' ? null : orgId,
      version: row['version'] as int?,
      etag: row['etag'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      serverUpdatedAt: suaStr != null ? DateTime.parse(suaStr) : null,
      state: SyncRecordState.values.byName(row['state'] as String),
      deleted: (row['deleted'] as int?) == 1,
      payload: payload,
    );
  }
}

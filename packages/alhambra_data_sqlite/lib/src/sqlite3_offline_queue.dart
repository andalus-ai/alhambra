import 'dart:convert';

import 'package:alhambra_data/alhambra_data.dart';

import 'sqlite3_database.dart';

const _kTable = 'offline_queue';

/// SQLite-backed [OfflineQueue] implementation.
///
/// Operations are stored in an `offline_queue` table. The queue:
/// - Deduplicates by `id` (INSERT OR IGNORE)
/// - Returns only `pending` and `retrying` ops from [pending()]
/// - Orders pending ops by `created_at` ASC (FIFO replay)
final class Sqlite3OfflineQueue implements OfflineQueue {
  final Sqlite3Database _db;

  Sqlite3OfflineQueue(this._db);

  /// Creates the backing table if it does not exist.
  Future<void> init() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_kTable (
        id               TEXT PRIMARY KEY,
        idempotency_key  TEXT NOT NULL,
        resource_type    TEXT NOT NULL,
        resource_id      TEXT NOT NULL,
        operation        TEXT NOT NULL,
        organization_id  TEXT,
        base_version     INTEGER,
        created_at       TEXT NOT NULL,
        attempt_count    INTEGER NOT NULL DEFAULT 0,
        last_attempt_at  TEXT,
        status           TEXT NOT NULL DEFAULT 'pending',
        payload          TEXT
      )
    ''');
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    await _db.execute(
      '''
      INSERT OR IGNORE INTO $_kTable
        (id, idempotency_key, resource_type, resource_id, operation,
         organization_id, base_version, created_at, attempt_count,
         last_attempt_at, status, payload)
      VALUES
        (:id, :ik, :rt, :ri, :op, :oid, :bv, :ca, :ac, :la, :st, :pl)
      ''',
      parameters: _toRow(operation),
    );
  }

  @override
  Future<List<SyncOperation>> pending() async {
    final rows = await _db.query(
      "SELECT * FROM $_kTable WHERE status IN ('pending','retrying') "
      "ORDER BY created_at ASC",
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> updateStatus(SyncOperation operation) async {
    await _db.execute(
      '''
      UPDATE $_kTable SET
        status          = :st,
        attempt_count   = :ac,
        last_attempt_at = :la
      WHERE id = :id
      ''',
      parameters: {
        'id': operation.id,
        'st': operation.status.name,
        'ac': operation.attemptCount,
        'la': operation.lastAttemptAt?.toIso8601String(),
      },
    );
  }

  @override
  Future<void> remove(String operationId) async {
    await _db.execute(
      'DELETE FROM $_kTable WHERE id = :id',
      parameters: {'id': operationId},
    );
  }

  @override
  Future<void> clear() async {
    await _db.execute('DELETE FROM $_kTable');
  }

  @override
  Future<int> count() async {
    final rows = await _db.query('SELECT COUNT(*) as n FROM $_kTable');
    return (rows.first['n'] as int?) ?? 0;
  }

  // ── Serialisation helpers ─────────────────────────────────────────────────

  static Map<String, Object?> _toRow(SyncOperation op) => {
        'id': op.id,
        'ik': op.idempotencyKey,
        'rt': op.resourceType,
        'ri': op.resourceId,
        'op': op.operation,
        'oid': op.organizationId,
        'bv': op.baseVersion,
        'ca': op.createdAt.toIso8601String(),
        'ac': op.attemptCount,
        'la': op.lastAttemptAt?.toIso8601String(),
        'st': op.status.name,
        'pl': op.payload.isNotEmpty ? jsonEncode(op.payload) : null,
      };

  static SyncOperation _fromRow(Map<String, Object?> row) {
    final payloadStr = row['payload'] as String?;
    final payload = payloadStr != null
        ? (jsonDecode(payloadStr) as Map).cast<String, Object?>()
        : <String, Object?>{};
    final laStr = row['last_attempt_at'] as String?;

    return SyncOperation(
      id: row['id'] as String,
      idempotencyKey: row['idempotency_key'] as String,
      resourceType: row['resource_type'] as String,
      resourceId: row['resource_id'] as String,
      operation: row['operation'] as String,
      organizationId: row['organization_id'] as String?,
      baseVersion: row['base_version'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      attemptCount: row['attempt_count'] as int? ?? 0,
      lastAttemptAt: laStr != null ? DateTime.parse(laStr) : null,
      status: SyncOperationStatus.values.byName(row['status'] as String),
      payload: payload,
    );
  }
}

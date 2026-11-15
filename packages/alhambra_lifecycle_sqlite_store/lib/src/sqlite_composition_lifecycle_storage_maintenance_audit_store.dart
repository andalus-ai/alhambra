import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:sqlite3/sqlite3.dart';

/// Queryable maintenance audit table backed by a host-owned SQLite database.
///
/// Pass the [database] from [SqliteCompositionLifecycleEventStore] to keep
/// event and maintenance history in the same database. This adapter creates
/// only its own table and indexes; it never closes the host-owned connection.
final class SqliteCompositionLifecycleStorageMaintenanceAuditStore
    implements CompositionLifecycleStorageMaintenanceAuditStore {
  final Database database;

  SqliteCompositionLifecycleStorageMaintenanceAuditStore({
    required this.database,
  }) {
    _createSchema();
  }

  void _createSchema() {
    database.execute('''
      CREATE TABLE IF NOT EXISTS lifecycle_maintenance_audit (
        operation_id TEXT NOT NULL,
        operation_id_sort_key TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at_micros INTEGER NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (operation_id, status)
      )
    ''');
    database.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_maintenance_one_terminal "
      "ON lifecycle_maintenance_audit(operation_id) WHERE status != 'started'",
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_audit_order '
      'ON lifecycle_maintenance_audit(started_at_micros, operation_id_sort_key, status)',
    );
  }

  @override
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  ) async {
    const codec = CompositionLifecycleStorageMaintenanceAuditJsonCodec();
    final payload = codec.encode(record);
    database.execute('BEGIN IMMEDIATE');
    try {
      final existing = database.select(
        'SELECT payload FROM lifecycle_maintenance_audit '
        'WHERE operation_id = ? AND status = ?',
        [record.operationId, record.status.name],
      );
      if (existing.isNotEmpty) {
        if (existing.single['payload'] == payload) {
          database.execute('COMMIT');
          return;
        }
        throw CompositionLifecycleStorageMaintenanceAuditIdentityConflictException(
          operationId: record.operationId,
          status: record.status,
        );
      }
      if (record.status != CompositionLifecycleStorageMaintenanceOperationStatus.started) {
        final terminal = database.select(
          'SELECT status FROM lifecycle_maintenance_audit '
          'WHERE operation_id = ? AND status != ?',
          [record.operationId, CompositionLifecycleStorageMaintenanceOperationStatus.started.name],
        );
        if (terminal.isNotEmpty) {
          throw CompositionLifecycleStorageMaintenanceAuditIdentityConflictException(
            operationId: record.operationId,
            status: record.status,
          );
        }
      }
      database.execute(
        'INSERT INTO lifecycle_maintenance_audit '
        '(operation_id, operation_id_sort_key, status, started_at_micros, payload) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          record.operationId,
          _maintenanceOperationIdSortKey(record.operationId),
          record.status.name,
          record.startedAt.toUtc().microsecondsSinceEpoch,
          payload,
        ],
      );
      database.execute('COMMIT');
    } on Object {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<List<CompositionLifecycleStorageMaintenanceOperationRecord>> query(
    CompositionLifecycleStorageMaintenanceAuditQuery query,
  ) async {
    final clauses = <String>[];
    final parameters = <Object?>[];
    void add(String clause, Object? value) {
      clauses.add(clause);
      parameters.add(value);
    }

    if (query.operationId != null) add('operation_id = ?', query.operationId);
    if (query.status != null) add('status = ?', query.status!.name);
    if (query.from != null) {
      add('started_at_micros >= ?', query.from!.toUtc().microsecondsSinceEpoch);
    }
    if (query.to != null) {
      add('started_at_micros <= ?', query.to!.toUtc().microsecondsSinceEpoch);
    }
    if (query.after != null) {
      final cursor = query.after!;
      final micros = cursor.startedAt.toUtc().microsecondsSinceEpoch;
      final sortKey = _maintenanceOperationIdSortKey(cursor.operationId);
      clauses.add('(started_at_micros > ? OR '
          '(started_at_micros = ? AND operation_id_sort_key > ?) OR '
          '(started_at_micros = ? AND operation_id_sort_key = ? AND status > ?))');
      parameters
        ..add(micros)
        ..add(micros)
        ..add(sortKey)
        ..add(micros)
        ..add(sortKey)
        ..add(cursor.status.name);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    parameters.add(query.limit);
    final rows = database.select(
      'SELECT payload FROM lifecycle_maintenance_audit $where '
      'ORDER BY started_at_micros, operation_id_sort_key, status LIMIT ?',
      parameters,
    );
    return List.unmodifiable(rows.map((row) =>
        const CompositionLifecycleStorageMaintenanceAuditJsonCodec()
            .decode(row['payload'] as String)));
  }
}

String _maintenanceOperationIdSortKey(String value) => value.codeUnits
    .map((unit) => unit.toRadixString(16).padLeft(4, '0'))
    .join();

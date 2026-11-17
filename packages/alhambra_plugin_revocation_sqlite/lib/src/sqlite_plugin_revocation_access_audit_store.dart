import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Durable SQLite sink for plugin-revocation administrative access decisions.
///
/// The caller owns [database] and is responsible for opening, configuring and
/// closing it. Call [migrate] before using this adapter. A separate database
/// connection may be used from the revocation journal/outbox store.
final class SqlitePluginRevocationAccessAuditStore
    implements
        PluginRevocationOperationsAccessAuditStore,
        PluginRevocationOperationsAccessAuditInspectionStore {
  final sq.Database database;

  SqlitePluginRevocationAccessAuditStore(this.database);

  /// Creates the append-only audit table and its scope/time index.
  void migrate() {
    database.execute('''
      CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit (
        audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
        actor_id TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        decision TEXT NOT NULL CHECK (decision IN ('allowed', 'denied')),
        denial_code TEXT,
        occurred_at TEXT NOT NULL,
        resource TEXT,
        page_size INTEGER,
        continuation_requested INTEGER,
        query_fingerprint TEXT
      )
    ''');
    database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_access_audit_scope_time
      ON alhambra_plugin_revocation_access_audit(scope_id, occurred_at DESC, audit_id DESC)
    ''');
  }

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('''
        INSERT INTO alhambra_plugin_revocation_access_audit (
          actor_id, scope_id, decision, denial_code, occurred_at,
          resource, page_size, continuation_requested, query_fingerprint
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        audit.actorId,
        audit.scopeId,
        audit.decision.name,
        audit.denialCode,
        _encodeDate(audit.occurredAt),
        audit.resource,
        audit.pageSize,
        audit.continuationRequested == null
            ? null
            : (audit.continuationRequested! ? 1 : 0),
        audit.queryFingerprint,
      ]);
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<List<PluginRevocationOperationsAccessAudit>> readAccessAudits({
    required String scopeId,
    int limit = 100,
    DateTime? fromInclusive,
    DateTime? toExclusive,
  }) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 500.');
    }
    if (fromInclusive != null &&
        toExclusive != null &&
        !fromInclusive.isBefore(toExclusive)) {
      throw ArgumentError('fromInclusive must be before toExclusive.');
    }

    final clauses = <String>['scope_id = ?'];
    final parameters = <Object?>[scopeId];
    if (fromInclusive != null) {
      clauses.add('occurred_at >= ?');
      parameters.add(_encodeDate(fromInclusive));
    }
    if (toExclusive != null) {
      clauses.add('occurred_at < ?');
      parameters.add(_encodeDate(toExclusive));
    }
    parameters.add(limit);

    final rows = database.select('''
      SELECT actor_id, scope_id, decision, denial_code, occurred_at,
             resource, page_size, continuation_requested, query_fingerprint
      FROM alhambra_plugin_revocation_access_audit
      WHERE ${clauses.join(' AND ')}
      ORDER BY occurred_at DESC, audit_id DESC
      LIMIT ?
    ''', parameters);

    return rows.map((row) {
      final continuation = row['continuation_requested'] as int?;
      return PluginRevocationOperationsAccessAudit(
        actorId: row['actor_id']! as String,
        scopeId: row['scope_id']! as String,
        decision: PluginRevocationOperationsAccessDecision.values
            .byName(row['decision']! as String),
        denialCode: row['denial_code'] as String?,
        occurredAt: DateTime.parse(row['occurred_at']! as String).toUtc(),
        resource: row['resource'] as String?,
        pageSize: row['page_size'] as int?,
        continuationRequested:
            continuation == null ? null : continuation == 1,
        queryFingerprint: row['query_fingerprint'] as String?,
      );
    }).toList(growable: false);
  }

  static String _encodeDate(DateTime value) {
    final iso = value.toUtc().toIso8601String();
    final dot = iso.indexOf('.');
    final fraction = dot < 0 ? '000000' : iso.substring(dot + 1, iso.length - 1);
    final prefix = dot < 0 ? iso.substring(0, iso.length - 1) : iso.substring(0, dot);
    return '$prefix.${fraction.padRight(6, '0').substring(0, 6)}Z';
  }
}

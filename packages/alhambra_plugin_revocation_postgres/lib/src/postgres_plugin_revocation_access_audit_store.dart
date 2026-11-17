import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:postgres/postgres.dart';

/// Durable PostgreSQL sink for plugin-revocation administrative access
/// decisions. The caller owns [pool] and its lifecycle.
final class PostgresPluginRevocationAccessAuditStore
    implements
        PluginRevocationOperationsAccessAuditStore,
        PluginRevocationOperationsAccessAuditInspectionStore {
  final Pool<dynamic> pool;

  PostgresPluginRevocationAccessAuditStore(this.pool);

  /// Creates the append-only audit table and scope/time index.
  Future<void> migrate() async {
    await pool.runTx((tx) async {
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit (
          audit_id BIGSERIAL PRIMARY KEY,
          actor_id TEXT NOT NULL,
          scope_id TEXT NOT NULL,
          decision TEXT NOT NULL CHECK (decision IN ('allowed', 'denied')),
          denial_code TEXT,
          occurred_at TIMESTAMPTZ NOT NULL,
          resource TEXT,
          page_size INTEGER CHECK (page_size IS NULL OR page_size BETWEEN 1 AND 500),
          continuation_requested BOOLEAN,
          query_fingerprint TEXT
        )
      ''');
      await tx.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_access_audit_scope_time
        ON alhambra_plugin_revocation_access_audit(scope_id, occurred_at DESC, audit_id DESC)
      ''');
    });
  }

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    await pool.runTx((tx) async {
      await tx.execute(r'''
        INSERT INTO alhambra_plugin_revocation_access_audit (
          actor_id, scope_id, decision, denial_code, occurred_at,
          resource, page_size, continuation_requested, query_fingerprint
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ''', parameters: [
        audit.actorId,
        audit.scopeId,
        audit.decision.name,
        audit.denialCode,
        audit.occurredAt.toUtc(),
        audit.resource,
        audit.pageSize,
        audit.continuationRequested,
        audit.queryFingerprint,
      ]);
    });
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

    final clauses = <String>['scope_id = $1'];
    final parameters = <Object?>[scopeId];
    if (fromInclusive != null) {
      parameters.add(fromInclusive.toUtc());
      clauses.add('occurred_at >= $${parameters.length}');
    }
    if (toExclusive != null) {
      parameters.add(toExclusive.toUtc());
      clauses.add('occurred_at < $${parameters.length}');
    }
    parameters.add(limit);
    final limitParameter = parameters.length;

    final rows = await pool.execute(
      'SELECT actor_id, scope_id, decision, denial_code, occurred_at, '
      'resource, page_size, continuation_requested, query_fingerprint '
      'FROM alhambra_plugin_revocation_access_audit '
      'WHERE ${clauses.join(' AND ')} '
      'ORDER BY occurred_at DESC, audit_id DESC LIMIT $$limitParameter',
      parameters: parameters,
    );

    return rows.map((row) {
      final value = row.toColumnMap();
      return PluginRevocationOperationsAccessAudit(
        actorId: value['actor_id'] as String,
        scopeId: value['scope_id'] as String,
        decision: PluginRevocationOperationsAccessDecision.values
            .byName(value['decision'] as String),
        denialCode: value['denial_code'] as String?,
        occurredAt: (value['occurred_at'] as DateTime).toUtc(),
        resource: value['resource'] as String?,
        pageSize: value['page_size'] as int?,
        continuationRequested: value['continuation_requested'] as bool?,
        queryFingerprint: value['query_fingerprint'] as String?,
      );
    }).toList(growable: false);
  }
}

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:postgres/postgres.dart';

/// Durable PostgreSQL sink for plugin-revocation administrative access
/// decisions. The caller owns [pool] and its lifecycle.
final class PostgresPluginRevocationAccessAuditStore
    implements
        PluginRevocationOperationsAccessAuditStore,
        PluginRevocationOperationsAccessAuditInspectionStore,
        PluginRevocationAccessAuditChainStore,
        PluginRevocationAccessAuditCheckpointChainVerifier {
  final Pool<dynamic> pool;

  PostgresPluginRevocationAccessAuditStore(this.pool);

  /// Creates the append-only audit table and scope/time index.
  Future<void> migrate() async {
    await pool.runTx((tx) async {
      final existingChain = await tx.execute(
        "SELECT to_regclass('alhambra_plugin_revocation_access_audit_chain') AS chain_table",
      );
      final chainTableExisted =
          existingChain.first.toColumnMap()['chain_table'] != null;
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
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit_chain (
          scope_id TEXT NOT NULL,
          sequence_number BIGINT NOT NULL,
          audit_id BIGINT NOT NULL UNIQUE,
          previous_hash TEXT NOT NULL,
          canonical_payload TEXT NOT NULL,
          entry_hash TEXT NOT NULL,
          PRIMARY KEY (scope_id, sequence_number)
        )
      ''');
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit_chain_head (
          scope_id TEXT PRIMARY KEY,
          sequence_number BIGINT NOT NULL,
          head_hash TEXT NOT NULL
        )
      ''');
      await tx.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_access_audit_scope_time
        ON alhambra_plugin_revocation_access_audit(scope_id, occurred_at DESC, audit_id DESC)
      ''');
      if (!chainTableExisted) {
        // Initial activation backfills historical rows once. Later migrations
        // never silently repair or rewrite a chain that already exists.
        final oldRows = await tx.execute('''
          SELECT audit_id, actor_id, scope_id, decision, denial_code,
                 occurred_at, resource, page_size, continuation_requested,
                 query_fingerprint
          FROM alhambra_plugin_revocation_access_audit
          ORDER BY scope_id ASC, audit_id ASC
        ''');
        for (final row in oldRows) {
          final value = row.toColumnMap();
          final audit = _auditFromRow(value);
          final heads = await tx.execute(
            'SELECT sequence_number, head_hash '
            'FROM alhambra_plugin_revocation_access_audit_chain_head '
            'WHERE scope_id = $1',
            parameters: [audit.scopeId],
          );
          final sequence = heads.isEmpty
              ? 1
              : (heads.first.toColumnMap()['sequence_number'] as int) + 1;
          final previousHash = heads.isEmpty
              ? PluginRevocationAccessAuditChainCodec.genesisHash
              : heads.first.toColumnMap()['head_hash'] as String;
          final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
          final entryHash = PluginRevocationAccessAuditChainCodec.hash(
            previousHash: previousHash,
            canonicalPayload: payload,
          );
          await tx.execute(r'''
            INSERT INTO alhambra_plugin_revocation_access_audit_chain (
              scope_id, sequence_number, audit_id, previous_hash,
              canonical_payload, entry_hash
            ) VALUES ($1, $2, $3, $4, $5, $6)
          ''', parameters: [
            audit.scopeId,
            sequence,
            value['audit_id'],
            previousHash,
            payload,
            entryHash,
          ]);
          await tx.execute(r'''
            INSERT INTO alhambra_plugin_revocation_access_audit_chain_head (
              scope_id, sequence_number, head_hash
            ) VALUES ($1, $2, $3)
            ON CONFLICT (scope_id) DO UPDATE SET
              sequence_number = EXCLUDED.sequence_number,
              head_hash = EXCLUDED.head_hash
          ''', parameters: [audit.scopeId, sequence, entryHash]);
        }
      }
    });
  }

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    await pool.runTx((tx) async {
      // Serialize appenders for this scope, including first-write races.
      await tx.execute(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        parameters: [audit.scopeId],
      );
      final inserted = await tx.execute(r'''
        INSERT INTO alhambra_plugin_revocation_access_audit (
          actor_id, scope_id, decision, denial_code, occurred_at,
          resource, page_size, continuation_requested, query_fingerprint
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING audit_id
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
      final auditId = inserted.first.toColumnMap()['audit_id'] as int;
      final heads = await tx.execute(
        'SELECT sequence_number, head_hash '
        'FROM alhambra_plugin_revocation_access_audit_chain_head '
        'WHERE scope_id = $1 FOR UPDATE',
        parameters: [audit.scopeId],
      );
      final sequence = heads.isEmpty
          ? 1
          : (heads.first.toColumnMap()['sequence_number'] as int) + 1;
      final previousHash = heads.isEmpty
          ? PluginRevocationAccessAuditChainCodec.genesisHash
          : heads.first.toColumnMap()['head_hash'] as String;
      final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
      final entryHash = PluginRevocationAccessAuditChainCodec.hash(
        previousHash: previousHash,
        canonicalPayload: payload,
      );
      await tx.execute(r'''
        INSERT INTO alhambra_plugin_revocation_access_audit_chain (
          scope_id, sequence_number, audit_id, previous_hash,
          canonical_payload, entry_hash
        ) VALUES ($1, $2, $3, $4, $5, $6)
      ''', parameters: [
        audit.scopeId, sequence, auditId, previousHash, payload, entryHash,
      ]);
      await tx.execute(r'''
        INSERT INTO alhambra_plugin_revocation_access_audit_chain_head (
          scope_id, sequence_number, head_hash
        ) VALUES ($1, $2, $3)
        ON CONFLICT (scope_id) DO UPDATE SET
          sequence_number = EXCLUDED.sequence_number,
          head_hash = EXCLUDED.head_hash
      ''', parameters: [audit.scopeId, sequence, entryHash]);
    });
  }

  @override
  Future<PluginRevocationAccessAuditChainVerification>
      verifyAccessAuditChain({required String scopeId}) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    final rows = await pool.execute(r'''
      SELECT c.sequence_number, c.previous_hash, c.canonical_payload,
             c.entry_hash, a.actor_id, a.scope_id, a.decision, a.denial_code,
             a.occurred_at, a.resource, a.page_size,
             a.continuation_requested, a.query_fingerprint
      FROM alhambra_plugin_revocation_access_audit_chain c
      JOIN alhambra_plugin_revocation_access_audit a ON a.audit_id = c.audit_id
      WHERE c.scope_id = $1
      ORDER BY c.sequence_number ASC
    ''', parameters: [scopeId]);
    var expectedSequence = 1;
    var previousHash = PluginRevocationAccessAuditChainCodec.genesisHash;
    for (final row in rows) {
      final value = row.toColumnMap();
      final sequence = value['sequence_number'] as int;
      final audit = _auditFromRow(value);
      final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
      final expectedHash = PluginRevocationAccessAuditChainCodec.hash(
        previousHash: previousHash,
        canonicalPayload: payload,
      );
      final actualHash = value['entry_hash'] as String;
      if (sequence != expectedSequence ||
          value['previous_hash'] != previousHash ||
          value['canonical_payload'] != payload ||
          actualHash != expectedHash) {
        return PluginRevocationAccessAuditChainVerification(
          scopeId: scopeId,
          valid: false,
          entriesVerified: expectedSequence - 1,
          failedSequence: sequence,
          expectedHash: expectedHash,
          actualHash: actualHash,
          headHash: previousHash,
        );
      }
      previousHash = actualHash;
      expectedSequence++;
    }
    final auditCountRows = await pool.execute(
      'SELECT COUNT(*) AS total FROM alhambra_plugin_revocation_access_audit '
      'WHERE scope_id = $1',
      parameters: [scopeId],
    );
    final chainCountRows = await pool.execute(
      'SELECT COUNT(*) AS total FROM alhambra_plugin_revocation_access_audit_chain '
      'WHERE scope_id = $1',
      parameters: [scopeId],
    );
    final auditCount =
        (auditCountRows.first.toColumnMap()['total'] as int);
    final chainCount =
        (chainCountRows.first.toColumnMap()['total'] as int);
    if (auditCount != rows.length || chainCount != rows.length) {
      return PluginRevocationAccessAuditChainVerification(
        scopeId: scopeId,
        valid: false,
        entriesVerified: rows.length,
        failedSequence: rows.length + 1,
        expectedHash: previousHash,
        headHash: previousHash,
      );
    }

    final heads = await pool.execute(
      'SELECT sequence_number, head_hash '
      'FROM alhambra_plugin_revocation_access_audit_chain_head '
      'WHERE scope_id = $1',
      parameters: [scopeId],
    );
    if (rows.isEmpty && heads.isNotEmpty ||
        rows.isNotEmpty &&
            (heads.isEmpty ||
                heads.first.toColumnMap()['sequence_number'] != rows.length ||
                heads.first.toColumnMap()['head_hash'] != previousHash)) {
      return PluginRevocationAccessAuditChainVerification(
        scopeId: scopeId,
        valid: false,
        entriesVerified: rows.length,
        failedSequence: rows.length + 1,
        expectedHash: previousHash,
        actualHash:
            heads.isEmpty ? null : heads.first.toColumnMap()['head_hash'] as String,
        headHash: previousHash,
      );
    }
    return PluginRevocationAccessAuditChainVerification(
      scopeId: scopeId,
      valid: true,
      entriesVerified: rows.length,
      headHash: previousHash,
    );
  }

  @override
  Future<bool> containsVerifiedHead({
    required String scopeId,
    required int sequence,
    required String headHash,
  }) async {
    final rows = await pool.execute(
      'SELECT entry_hash FROM alhambra_plugin_revocation_access_audit_chain '
      'WHERE scope_id = $1 AND sequence_number = $2',
      parameters: [scopeId, sequence],
    );
    return rows.isNotEmpty &&
        rows.first.toColumnMap()['entry_hash'] == headHash;
  }

  PluginRevocationOperationsAccessAudit _auditFromRow(
    Map<String, dynamic> value,
  ) =>
      PluginRevocationOperationsAccessAudit(
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
      clauses.add('occurred_at >= ' + r'$' + parameters.length.toString());
    }
    if (toExclusive != null) {
      parameters.add(toExclusive.toUtc());
      clauses.add('occurred_at < ' + r'$' + parameters.length.toString());
    }
    parameters.add(limit);
    final limitParameter = parameters.length;

    final rows = await pool.execute(
      'SELECT actor_id, scope_id, decision, denial_code, occurred_at, '
      'resource, page_size, continuation_requested, query_fingerprint '
      'FROM alhambra_plugin_revocation_access_audit '
      'WHERE ${clauses.join(' AND ')} '
      'ORDER BY occurred_at DESC, audit_id DESC LIMIT ' + r'$' + limitParameter.toString(),
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

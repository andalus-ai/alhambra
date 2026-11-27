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
        PluginRevocationOperationsAccessAuditInspectionStore,
        PluginRevocationAccessAuditChainStore,
        PluginRevocationAccessAuditCheckpointChainVerifier {
  final sq.Database database;

  SqlitePluginRevocationAccessAuditStore(this.database);

  /// Creates the append-only audit table and its scope/time index.
  void migrate() {
    final chainTableExisted = database.select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'alhambra_plugin_revocation_access_audit_chain'",
    ).isNotEmpty;
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
      CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit_chain (
        scope_id TEXT NOT NULL,
        sequence_number INTEGER NOT NULL,
        audit_id INTEGER NOT NULL UNIQUE,
        previous_hash TEXT NOT NULL,
        canonical_payload TEXT NOT NULL,
        entry_hash TEXT NOT NULL,
        PRIMARY KEY (scope_id, sequence_number)
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_access_audit_chain_head (
        scope_id TEXT PRIMARY KEY,
        sequence_number INTEGER NOT NULL,
        head_hash TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_access_audit_scope_time
      ON alhambra_plugin_revocation_access_audit(scope_id, occurred_at DESC, audit_id DESC)
    ''');
    if (!chainTableExisted) {
      _backfillExistingAuditRows();
    }
  }

  /// Establishes the initial chain from pre-existing audit rows exactly once.
  /// Subsequent migrations never silently repair or rewrite an existing chain.
  void _backfillExistingAuditRows() {
    database.execute('BEGIN IMMEDIATE');
    try {
      final rows = database.select('''
        SELECT audit_id, actor_id, scope_id, decision, denial_code, occurred_at,
               resource, page_size, continuation_requested, query_fingerprint
        FROM alhambra_plugin_revocation_access_audit
        ORDER BY scope_id ASC, audit_id ASC
      ''');
      for (final row in rows) {
        final audit = _auditFromRow(row);
        final heads = database.select(
          'SELECT sequence_number, head_hash '
          'FROM alhambra_plugin_revocation_access_audit_chain_head '
          'WHERE scope_id = ?',
          [audit.scopeId],
        );
        final sequence = heads.isEmpty
            ? 1
            : (heads.first['sequence_number'] as int) + 1;
        final previousHash = heads.isEmpty
            ? PluginRevocationAccessAuditChainCodec.genesisHash
            : heads.first['head_hash'] as String;
        final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
        final entryHash = PluginRevocationAccessAuditChainCodec.hash(
          previousHash: previousHash,
          canonicalPayload: payload,
        );
        database.execute('''
          INSERT INTO alhambra_plugin_revocation_access_audit_chain (
            scope_id, sequence_number, audit_id, previous_hash,
            canonical_payload, entry_hash
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''', [
          audit.scopeId,
          sequence,
          row['audit_id'],
          previousHash,
          payload,
          entryHash,
        ]);
        database.execute('''
          INSERT INTO alhambra_plugin_revocation_access_audit_chain_head (
            scope_id, sequence_number, head_hash
          ) VALUES (?, ?, ?)
          ON CONFLICT(scope_id) DO UPDATE SET
            sequence_number = excluded.sequence_number,
            head_hash = excluded.head_hash
        ''', [audit.scopeId, sequence, entryHash]);
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
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
      final auditId = database.lastInsertRowId;
      final headRows = database.select(
        'SELECT sequence_number, head_hash '
        'FROM alhambra_plugin_revocation_access_audit_chain_head '
        'WHERE scope_id = ?',
        [audit.scopeId],
      );
      final sequence = headRows.isEmpty
          ? 1
          : (headRows.first['sequence_number'] as int) + 1;
      final previousHash = headRows.isEmpty
          ? PluginRevocationAccessAuditChainCodec.genesisHash
          : headRows.first['head_hash'] as String;
      final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
      final entryHash = PluginRevocationAccessAuditChainCodec.hash(
        previousHash: previousHash,
        canonicalPayload: payload,
      );
      database.execute('''
        INSERT INTO alhambra_plugin_revocation_access_audit_chain (
          scope_id, sequence_number, audit_id, previous_hash,
          canonical_payload, entry_hash
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''', [audit.scopeId, sequence, auditId, previousHash, payload, entryHash]);
      database.execute('''
        INSERT INTO alhambra_plugin_revocation_access_audit_chain_head (
          scope_id, sequence_number, head_hash
        ) VALUES (?, ?, ?)
        ON CONFLICT(scope_id) DO UPDATE SET
          sequence_number = excluded.sequence_number,
          head_hash = excluded.head_hash
      ''', [audit.scopeId, sequence, entryHash]);
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<PluginRevocationAccessAuditChainVerification>
      verifyAccessAuditChain({required String scopeId}) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    final rows = database.select('''
      SELECT c.sequence_number, c.previous_hash, c.canonical_payload,
             c.entry_hash, a.actor_id, a.scope_id, a.decision, a.denial_code,
             a.occurred_at, a.resource, a.page_size,
             a.continuation_requested, a.query_fingerprint
      FROM alhambra_plugin_revocation_access_audit_chain c
      JOIN alhambra_plugin_revocation_access_audit a ON a.audit_id = c.audit_id
      WHERE c.scope_id = ?
      ORDER BY c.sequence_number ASC
    ''', [scopeId]);
    var expectedSequence = 1;
    var previousHash = PluginRevocationAccessAuditChainCodec.genesisHash;
    for (final row in rows) {
      final sequence = row['sequence_number'] as int;
      final audit = _auditFromRow(row);
      final payload = PluginRevocationAccessAuditChainCodec.canonicalPayload(audit);
      final expectedHash = PluginRevocationAccessAuditChainCodec.hash(
        previousHash: previousHash,
        canonicalPayload: payload,
      );
      final actualHash = row['entry_hash'] as String;
      if (sequence != expectedSequence ||
          row['previous_hash'] != previousHash ||
          row['canonical_payload'] != payload ||
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

    final auditCount = database.select(
      'SELECT COUNT(*) AS total FROM alhambra_plugin_revocation_access_audit '
      'WHERE scope_id = ?',
      [scopeId],
    ).first['total'] as int;
    final chainCount = database.select(
      'SELECT COUNT(*) AS total FROM alhambra_plugin_revocation_access_audit_chain '
      'WHERE scope_id = ?',
      [scopeId],
    ).first['total'] as int;
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

    final heads = database.select(
      'SELECT sequence_number, head_hash '
      'FROM alhambra_plugin_revocation_access_audit_chain_head '
      'WHERE scope_id = ?',
      [scopeId],
    );
    if (rows.isEmpty && heads.isNotEmpty ||
        rows.isNotEmpty &&
            (heads.isEmpty ||
                heads.first['sequence_number'] != rows.length ||
                heads.first['head_hash'] != previousHash)) {
      return PluginRevocationAccessAuditChainVerification(
        scopeId: scopeId,
        valid: false,
        entriesVerified: rows.length,
        failedSequence: rows.length + 1,
        expectedHash: previousHash,
        actualHash: heads.isEmpty ? null : heads.first['head_hash'] as String,
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
    final rows = database.select(
      'SELECT entry_hash FROM alhambra_plugin_revocation_access_audit_chain '
      'WHERE scope_id = ? AND sequence_number = ?',
      [scopeId, sequence],
    );
    return rows.isNotEmpty && rows.first['entry_hash'] == headHash;
  }

  PluginRevocationOperationsAccessAudit _auditFromRow(Map<String, Object?> row) {
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

    return rows
        .map((row) => _auditFromRow(row))
        .toList(growable: false);
  }

  static String _encodeDate(DateTime value) {
    final iso = value.toUtc().toIso8601String();
    final dot = iso.indexOf('.');
    final fraction = dot < 0 ? '000000' : iso.substring(dot + 1, iso.length - 1);
    final prefix = dot < 0 ? iso.substring(0, iso.length - 1) : iso.substring(0, dot);
    return '$prefix.${fraction.padRight(6, '0').substring(0, 6)}Z';
  }
}

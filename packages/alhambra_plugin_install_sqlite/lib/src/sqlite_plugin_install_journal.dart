import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Durable SQLite implementation of [PluginInstallRecoveryJournal].
///
/// Each mutation uses BEGIN IMMEDIATE and commits the current operation
/// projection and append-only event in one transaction. Independent store
/// instances sharing the same local database are serialized by SQLite.
///
/// Use a local filesystem with reliable SQLite locking. This adapter does not
/// provide filesystem promotion atomicity. Worker leases are provided by the
/// companion [SqlitePluginInstallOperationLeaseStore].
final class SqlitePluginInstallJournal implements
    FencedPluginInstallRecoveryJournal,
    PluginInstallManualReconciliationStore,
    PluginInstallAuditStore {
  final sq.Database _db;
  bool _closed = false;

  SqlitePluginInstallJournal(String path) : _db = sq.sqlite3.open(path) {
    _configure(path);
    _migrate();
  }

  SqlitePluginInstallJournal.memory() : _db = sq.sqlite3.openInMemory() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA synchronous = FULL');
    _migrate();
  }

  void _configure(String path) {
    _db.execute('PRAGMA busy_timeout = 5000');
    if (path != ':memory:') _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = FULL');
    _db.execute('PRAGMA foreign_keys = ON');
  }

  void close() {
    if (_closed) return;
    _db.dispose();
    _closed = true;
  }

  void _assertOpen() {
    if (_closed) throw StateError('SQLite plugin install journal is closed.');
  }

  void _migrate() {
    var version = _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version > 4) {
      throw UnsupportedError('Database schema version $version is newer than this adapter supports.');
    }
    if (version == 0) {
      _transaction(() {
        _db.execute('''
          CREATE TABLE plugin_install_operation (
            operation_id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            plugin_id TEXT NOT NULL,
            version TEXT NOT NULL,
            status TEXT NOT NULL,
            revision INTEGER NOT NULL CHECK (revision >= 1),
            updated_at TEXT NOT NULL,
            staging_handle TEXT,
            promoted_path TEXT,
            failure_code TEXT,
            content_hash TEXT,
            approved_by TEXT,
            approval_id TEXT,
            fencing_token INTEGER
          )
        ''');
        _db.execute('''
          CREATE UNIQUE INDEX idx_plugin_install_approval_id
          ON plugin_install_operation(approval_id)
          WHERE approval_id IS NOT NULL
        ''');
        _db.execute('''
          CREATE INDEX idx_plugin_install_unresolved
          ON plugin_install_operation(status, updated_at, operation_id)
        ''');
        _db.execute('''
          CREATE TABLE plugin_install_approval (
            approval_id TEXT PRIMARY KEY,
            operation_id TEXT NOT NULL,
            approved_by TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
          )
        ''');
        _db.execute('''
          CREATE TABLE plugin_install_event (
            event_id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_id TEXT NOT NULL,
            revision INTEGER NOT NULL,
            schema_version INTEGER NOT NULL,
            plugin_id TEXT NOT NULL,
            version TEXT NOT NULL,
            status TEXT NOT NULL,
            occurred_at TEXT NOT NULL,
            staging_handle TEXT,
            promoted_path TEXT,
            failure_code TEXT,
            content_hash TEXT,
            approved_by TEXT,
            approval_id TEXT,
            fencing_token INTEGER,
            UNIQUE(operation_id, revision),
            FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
          )
        ''');
        _db.execute('CREATE INDEX idx_plugin_install_event_history ON plugin_install_event(operation_id, revision)');
        _db.execute('''
          CREATE TABLE plugin_install_fence (
            operation_id TEXT PRIMARY KEY,
            highest_token INTEGER NOT NULL CHECK (highest_token >= 0)
          )
        ''');
        _db.execute('PRAGMA user_version = 2');
      });
      version = 2;
    }
    if (version == 1) {
      _transaction(() {
        _db.execute('ALTER TABLE plugin_install_operation ADD COLUMN fencing_token INTEGER');
        _db.execute('ALTER TABLE plugin_install_event ADD COLUMN fencing_token INTEGER');
        _db.execute('''
          CREATE TABLE plugin_install_fence (
            operation_id TEXT PRIMARY KEY,
            highest_token INTEGER NOT NULL CHECK (highest_token >= 0)
          )
        ''');
        _db.execute('PRAGMA user_version = 2');
      });
      version = 2;
    }
    if (version == 2) {
      _transaction(() {
        _db.execute('''
          CREATE TABLE plugin_install_manual_reconciliation (
            resolution_id TEXT PRIMARY KEY,
            operation_id TEXT NOT NULL,
            plugin_id TEXT NOT NULL,
            version TEXT NOT NULL,
            resolution TEXT NOT NULL,
            operator_id TEXT NOT NULL,
            evidence_summary TEXT NOT NULL,
            resolved_at TEXT NOT NULL,
            FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
          )
        ''');
        _db.execute('CREATE INDEX idx_plugin_install_manual_reconciliation_operation ON plugin_install_manual_reconciliation(operation_id, resolved_at)');
        _db.execute('PRAGMA user_version = 3');
      });
    }
    if (version == 3) {
      _transaction(() {
        _db.execute('CREATE INDEX idx_plugin_install_event_plugin_time ON plugin_install_event(plugin_id, occurred_at, event_id)');
        _db.execute('CREATE INDEX idx_plugin_install_event_status_time ON plugin_install_event(status, occurred_at, event_id)');
        _db.execute('CREATE INDEX idx_plugin_install_event_operator_time ON plugin_install_event(approved_by, occurred_at, event_id)');
        _db.execute('CREATE INDEX idx_plugin_install_event_time ON plugin_install_event(occurred_at, event_id)');
        _db.execute('PRAGMA user_version = 4');
      });
    }
  }

  T _transaction<T>(T Function() action) {
    _assertOpen();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static const int _schemaVersion = 4;
  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static DateTime _parseDate(Object? value) => DateTime.parse(value! as String).toUtc();

  static PluginInstallJournalEntry _entry(Map<String, Object?> row) =>
      PluginInstallJournalEntry(
        operationId: row['operation_id']! as String,
        pluginId: row['plugin_id']! as String,
        version: row['version']! as String,
        status: PluginInstallJournalStatus.values.byName(row['status']! as String),
        updatedAt: _parseDate(row['updated_at']),
        stagingHandle: row['staging_handle'] as String?,
        promotedPath: row['promoted_path'] as String?,
        failureCode: row['failure_code'] as String?,
        contentHash: row['content_hash'] as String?,
        approvedBy: row['approved_by'] as String?,
        approvalId: row['approval_id'] as String?,
        fencingToken: row['fencing_token'] as int?,
      );

  static const String _columns = '''
    operation_id, schema_version, plugin_id, version, status, updated_at,
    staging_handle, promoted_path, failure_code, content_hash, approved_by, approval_id, fencing_token
  ''';

  void _recordApproval(PluginInstallJournalEntry entry) {
    final approvalId = entry.approvalId;
    if (approvalId == null) return;
    _db.execute('''
      INSERT INTO plugin_install_approval
      (approval_id, operation_id, approved_by, recorded_at)
      VALUES (?, ?, ?, ?)
    ''', [approvalId, entry.operationId, entry.approvedBy, _date(entry.updatedAt)]);
  }

  void _insertEvent(PluginInstallJournalEntry entry, int revision) {
    _db.execute('''
      INSERT INTO plugin_install_event
      (operation_id, revision, schema_version, plugin_id, version, status,
       occurred_at, staging_handle, promoted_path, failure_code, content_hash,
       approved_by, approval_id, fencing_token)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      entry.operationId, revision, _schemaVersion, entry.pluginId, entry.version,
      entry.status.name, _date(entry.updatedAt), entry.stagingHandle,
      entry.promotedPath, entry.failureCode, entry.contentHash,
      entry.approvedBy, entry.approvalId, entry.fencingToken,
    ]);
  }

  void _assertAcceptedFence(String operationId, int? token) {
    final rows = _db.select(
      'SELECT highest_token FROM plugin_install_fence WHERE operation_id = ?',
      [operationId],
    );
    if (rows.isEmpty) {
      if (token != null) {
        throw StateError('A fencing token must be registered before journal writes.');
      }
      return;
    }
    if (token == null || rows.first['highest_token'] != token) {
      throw StateError('Journal write rejected because its fencing token is stale or missing.');
    }
  }

  @override
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  }) async {
    if (operationId.trim().isEmpty || fencingToken < 1) {
      throw ArgumentError('A non-empty operation ID and positive fencing token are required.');
    }
    return _transaction(() {
      final rows = _db.select(
        'SELECT highest_token FROM plugin_install_fence WHERE operation_id = ?',
        [operationId],
      );
      if (rows.isNotEmpty) {
        final highest = rows.first['highest_token']! as int;
        if (fencingToken < highest) return false;
        if (fencingToken == highest) return true;
        _db.execute(
          'UPDATE plugin_install_fence SET highest_token = ? WHERE operation_id = ?',
          [fencingToken, operationId],
        );
      } else {
        _db.execute(
          'INSERT INTO plugin_install_fence(operation_id, highest_token) VALUES (?, ?)',
          [operationId, fencingToken],
        );
      }
      return true;
    });
  }

  @override
  Future<void> write(PluginInstallJournalEntry entry) async {
    _validateEntry(entry);
    _transaction(() {
      _assertAcceptedFence(entry.operationId, entry.fencingToken);
      final rows = _db.select(
        'SELECT * FROM plugin_install_operation WHERE operation_id = ?',
        [entry.operationId],
      );
      if (rows.isEmpty) {
        _db.execute('''
          INSERT INTO plugin_install_operation ($_columns, revision)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ''', _values(entry));
        _recordApproval(entry);
        _insertEvent(entry, 1);
        return;
      }
      final current = Map<String, Object?>.from(rows.first);
      if (current['plugin_id'] != entry.pluginId || current['version'] != entry.version) {
        throw StateError('An operation ID cannot be reused for a different plugin or version.');
      }
      final currentStatus = PluginInstallJournalStatus.values.byName(current['status']! as String);
      if (_isTerminal(currentStatus)) {
        throw StateError('A terminal installation operation cannot be advanced.');
      }
      final revision = current['revision']! as int;
      final currentAt = _parseDate(current['updated_at']);
      if (entry.updatedAt.toUtc().isBefore(currentAt)) {
        throw StateError('Journal updates must not move updatedAt backwards.');
      }
      if (current['approval_id'] != entry.approvalId) _recordApproval(entry);
      _update(entry, revision + 1);
    });
  }

  void _update(PluginInstallJournalEntry entry, int revision) {
    _db.execute('''
      UPDATE plugin_install_operation SET
        schema_version = ?, plugin_id = ?, version = ?, status = ?, revision = ?,
        updated_at = ?, staging_handle = ?, promoted_path = ?, failure_code = ?,
        content_hash = ?, approved_by = ?, approval_id = ?, fencing_token = ?
      WHERE operation_id = ?
    ''', [
      _schemaVersion, entry.pluginId, entry.version, entry.status.name, revision,
      _date(entry.updatedAt), entry.stagingHandle, entry.promotedPath,
      entry.failureCode, entry.contentHash, entry.approvedBy, entry.approvalId,
      entry.fencingToken, entry.operationId,
    ]);
    _insertEvent(entry, revision);
  }

  static List<Object?> _values(PluginInstallJournalEntry entry) => [
    entry.operationId, _schemaVersion, entry.pluginId, entry.version,
    entry.status.name, _date(entry.updatedAt), entry.stagingHandle,
    entry.promotedPath, entry.failureCode, entry.contentHash,
    entry.approvedBy, entry.approvalId, entry.fencingToken,
  ];

  static bool _isTerminal(PluginInstallJournalStatus status) =>
      status == PluginInstallJournalStatus.committed ||
      status == PluginInstallJournalStatus.rolledBack ||
      status == PluginInstallJournalStatus.failed ||
      status == PluginInstallJournalStatus.manuallyReconciled;

  static void _validateEntry(PluginInstallJournalEntry entry) {
    for (final value in [entry.operationId, entry.pluginId, entry.version]) {
      if (value.trim().isEmpty) throw ArgumentError('Journal identity fields must not be empty.');
    }
    if (entry.approvalId != null &&
        (entry.approvedBy == null || entry.approvedBy!.trim().isEmpty)) {
      throw ArgumentError('An approval ID requires a non-empty operator identity.');
    }
    if (entry.approvalId != null && entry.approvalId!.trim().isEmpty) {
      throw ArgumentError('Approval ID must not be empty.');
    }
    for (final value in [entry.approvedBy, entry.approvalId]) {
      if (value != null &&
          (value.length > 256 || value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f))) {
        throw ArgumentError('Approval audit values must be bounded and contain no control characters.');
      }
    }
  }

  @override
  Future<List<PluginInstallJournalEntry>> unresolved() async {
    _assertOpen();
    final rows = _db.select('''
      SELECT * FROM plugin_install_operation
      WHERE status NOT IN ('committed', 'rolledBack', 'failed', 'manuallyReconciled')
      ORDER BY updated_at, operation_id
    ''');
    return List.unmodifiable(rows.map((row) => _entry(Map<String, Object?>.from(row))));
  }

  /// Reads the current projection for diagnostics and host reconciliation.
  Future<PluginInstallJournalEntry?> read(String operationId) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM plugin_install_operation WHERE operation_id = ?',
      [operationId],
    );
    return rows.isEmpty ? null : _entry(Map<String, Object?>.from(rows.first));
  }

  /// Returns immutable transition history in revision order.
  Future<List<PluginInstallJournalEntry>> history(String operationId) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT *, occurred_at AS updated_at FROM plugin_install_event WHERE operation_id = ? ORDER BY revision',
      [operationId],
    );
    return List.unmodifiable(rows.map((row) => _entry(Map<String, Object?>.from(row))));
  }

  @override
  Future<bool> compareAndSet({
    required String operationId,
    required PluginInstallJournalStatus expectedStatus,
    required DateTime expectedUpdatedAt,
    required PluginInstallJournalEntry replacement,
  }) async {
    _validateEntry(replacement);
    if (replacement.operationId != operationId) {
      throw ArgumentError('Replacement operation ID must match the claim.');
    }
    if (!replacement.updatedAt.toUtc().isAfter(expectedUpdatedAt.toUtc())) {
      throw ArgumentError('CAS replacement updatedAt must advance beyond the expected timestamp.');
    }
    return _transaction(() {
      final rows = _db.select(
        'SELECT * FROM plugin_install_operation WHERE operation_id = ?',
        [operationId],
      );
      _assertAcceptedFence(operationId, replacement.fencingToken);
      if (rows.isEmpty) return false;
      final current = Map<String, Object?>.from(rows.first);
      if (current['status'] != expectedStatus.name ||
          current['updated_at'] != _date(expectedUpdatedAt) ||
          current['plugin_id'] != replacement.pluginId ||
          current['version'] != replacement.version) {
        return false;
      }
      if (current['approval_id'] != replacement.approvalId) {
        _recordApproval(replacement);
      }
      _update(replacement, (current['revision']! as int) + 1);
      return true;
    });
  }
  /// Atomically records a human-verified resolution and closes an ambiguous
  /// operation. This method deliberately performs no filesystem or record
  /// mutation; the host must inspect and repair those systems separately.
  @override
  Future<bool> reconcileManually({
    required String operationId,
    required DateTime expectedUpdatedAt,
    required PluginInstallManualResolution resolution,
    required String resolutionId,
    required String operatorId,
    required String evidenceSummary,
    required DateTime resolvedAt,
  }) async {
    _validateAuditText(operationId, 'operationId', 256);
    _validateAuditText(resolutionId, 'resolutionId', 128);
    _validateAuditText(operatorId, 'operatorId', 256);
    _validateAuditText(evidenceSummary, 'evidenceSummary', 4000);
    if (!resolvedAt.toUtc().isAfter(expectedUpdatedAt.toUtc())) {
      throw ArgumentError('resolvedAt must advance beyond the expected journal timestamp.');
    }
    return _transaction(() {
      final rows = _db.select(
        'SELECT * FROM plugin_install_operation WHERE operation_id = ?',
        [operationId],
      );
      if (rows.isEmpty) return false;
      final current = Map<String, Object?>.from(rows.first);
      final status = PluginInstallJournalStatus.values.byName(current['status']! as String);
      if (status != PluginInstallJournalStatus.recoveryStarted &&
          status != PluginInstallJournalStatus.needsReconciliation) {
        return false;
      }
      if (current['updated_at'] != _date(expectedUpdatedAt)) return false;
      final token = current['fencing_token'] as int?;
      _assertAcceptedFence(operationId, token);
      final entry = PluginInstallJournalEntry(
        operationId: operationId,
        pluginId: current['plugin_id']! as String,
        version: current['version']! as String,
        status: PluginInstallJournalStatus.manuallyReconciled,
        updatedAt: resolvedAt.toUtc(),
        stagingHandle: current['staging_handle'] as String?,
        promotedPath: current['promoted_path'] as String?,
        failureCode: 'MANUAL_RECONCILED_${resolution.name.toUpperCase()}',
        contentHash: current['content_hash'] as String?,
        approvedBy: operatorId.trim(),
        approvalId: resolutionId.trim(),
        fencingToken: token,
      );
      _validateEntry(entry);
      _recordApproval(entry);
      _update(entry, (current['revision']! as int) + 1);
      _db.execute('''
        INSERT INTO plugin_install_manual_reconciliation
        (resolution_id, operation_id, plugin_id, version, resolution,
         operator_id, evidence_summary, resolved_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        resolutionId.trim(), operationId, entry.pluginId, entry.version,
        resolution.name, operatorId.trim(), evidenceSummary.trim(),
        _date(resolvedAt),
      ]);
      return true;
    });
  }

  /// Returns append-only operator reconciliation records in chronological order.
  @override
  Future<List<PluginInstallManualReconciliation>> manualReconciliations(
    String operationId,
  ) async {
    _assertOpen();
    final rows = _db.select('''
      SELECT * FROM plugin_install_manual_reconciliation
      WHERE operation_id = ?
      ORDER BY resolved_at, resolution_id
    ''', [operationId]);
    return List.unmodifiable(rows.map((row) => PluginInstallManualReconciliation(
      operationId: row['operation_id']! as String,
      pluginId: row['plugin_id']! as String,
      version: row['version']! as String,
      resolution: PluginInstallManualResolution.values.byName(row['resolution']! as String),
      resolutionId: row['resolution_id']! as String,
      operatorId: row['operator_id']! as String,
      evidenceSummary: row['evidence_summary']! as String,
      resolvedAt: _parseDate(row['resolved_at']),
    )));
  }


  /// Returns a bounded, newest-first page of append-only transition events.
  ///
  /// The event table is the source of truth. Manual-resolution details are
  /// joined by the event's approval ID; no second event is emitted for them.
  @override
  Future<List<PluginInstallAuditRecord>> queryAudit(
    PluginInstallAuditQuery query,
  ) async {
    _assertOpen();
    if (query.limit < 1 || query.limit > 500) {
      throw ArgumentError.value(query.limit, 'limit', 'Must be between 1 and 500.');
    }
    if (query.offset < 0) {
      throw ArgumentError.value(query.offset, 'offset', 'Must not be negative.');
    }
    for (final value in [query.operationId, query.pluginId, query.operatorId]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError('Audit filters must be null or non-empty.');
      }
    }
    if (query.from != null && query.to != null &&
        !query.from!.toUtc().isBefore(query.to!.toUtc())) {
      throw ArgumentError('Audit range must have from earlier than to.');
    }

    final predicates = <String>[];
    final parameters = <Object?>[];
    void add(String predicate, Object? value) {
      predicates.add(predicate);
      parameters.add(value);
    }

    if (query.operationId != null) add('e.operation_id = ?', query.operationId);
    if (query.pluginId != null) add('e.plugin_id = ?', query.pluginId);
    if (query.status != null) add('e.status = ?', query.status!.name);
    if (query.operatorId != null) add('e.approved_by = ?', query.operatorId);
    if (query.from != null) add('e.occurred_at >= ?', _date(query.from!));
    if (query.to != null) add('e.occurred_at < ?', _date(query.to!));

    final where = predicates.isEmpty ? '' : 'WHERE ${predicates.join(' AND ')}';
    final rows = _db.select('''
      SELECT e.operation_id, e.plugin_id, e.version, e.status,
             e.occurred_at, e.revision, e.approved_by, e.approval_id,
             e.failure_code, e.fencing_token,
             m.resolution AS manual_resolution,
             m.evidence_summary AS evidence_summary
      FROM plugin_install_event e
      LEFT JOIN plugin_install_manual_reconciliation m
        ON m.resolution_id = e.approval_id
      $where
      ORDER BY e.occurred_at DESC, e.event_id DESC
      LIMIT ? OFFSET ?
    ''', [...parameters, query.limit, query.offset]);

    return List.unmodifiable(rows.map((row) {
      final resolutionName = row['manual_resolution'] as String?;
      return PluginInstallAuditRecord(
        operationId: row['operation_id']! as String,
        pluginId: row['plugin_id']! as String,
        version: row['version']! as String,
        status: PluginInstallJournalStatus.values.byName(row['status']! as String),
        occurredAt: _parseDate(row['occurred_at']),
        revision: row['revision']! as int,
        operatorId: row['approved_by'] as String?,
        approvalId: row['approval_id'] as String?,
        failureCode: row['failure_code'] as String?,
        fencingToken: row['fencing_token'] as int?,
        manualResolution: resolutionName == null
            ? null
            : PluginInstallManualResolution.values.byName(resolutionName),
        evidenceSummary: row['evidence_summary'] as String?,
      );
    }));
  }

  static void _validateAuditText(String value, String field, int maxLength) {
    if (value.trim().isEmpty ||
        value.length > maxLength ||
        value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw ArgumentError('$field must be non-empty, bounded and contain no control characters.');
    }
  }

}

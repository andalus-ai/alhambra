import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Durable SQLite implementation of [PluginInstallRecoveryJournal].
///
/// Each mutation uses BEGIN IMMEDIATE and commits the current operation
/// projection and append-only event in one transaction. Independent store
/// instances sharing the same local database are serialized by SQLite.
///
/// Use a local filesystem with reliable SQLite locking. This adapter does not
/// provide filesystem promotion atomicity or installer-worker leases.
final class SqlitePluginInstallJournal implements PluginInstallRecoveryJournal {
  final sq.Database _db;
  bool _closed = false;

  SqlitePluginInstallJournal(String path) : _db = sq.sqlite3.open(path) {
    _configure(path);
    _migrate();
  }

  SqlitePluginInstallJournal.memory() : _db = sq.sqlite3.openInMemory() {
    _db.execute('PRAGMA foreign_keys = ON');
    _migrate();
  }

  void _configure(String path) {
    _db.execute('PRAGMA busy_timeout = 5000');
    if (path != ':memory:') _db.execute('PRAGMA journal_mode = WAL');
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
    final version = _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version > 1) {
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
            approval_id TEXT
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
            UNIQUE(operation_id, revision),
            FOREIGN KEY(operation_id) REFERENCES plugin_install_operation(operation_id)
          )
        ''');
        _db.execute('CREATE INDEX idx_plugin_install_event_history ON plugin_install_event(operation_id, revision)');
        _db.execute('''
          CREATE UNIQUE INDEX idx_plugin_install_event_approval_id
          ON plugin_install_event(approval_id)
          WHERE approval_id IS NOT NULL
        ''');
        _db.execute('PRAGMA user_version = 1');
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

  static const int _schemaVersion = 1;
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
      );

  static const String _columns = '''
    operation_id, schema_version, plugin_id, version, status, updated_at,
    staging_handle, promoted_path, failure_code, content_hash, approved_by, approval_id
  ''';

  void _insertEvent(PluginInstallJournalEntry entry, int revision) {
    _db.execute('''
      INSERT INTO plugin_install_event
      (operation_id, revision, schema_version, plugin_id, version, status,
       occurred_at, staging_handle, promoted_path, failure_code, content_hash,
       approved_by, approval_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      entry.operationId, revision, _schemaVersion, entry.pluginId, entry.version,
      entry.status.name, _date(entry.updatedAt), entry.stagingHandle,
      entry.promotedPath, entry.failureCode, entry.contentHash,
      entry.approvedBy, entry.approvalId,
    ]);
  }

  @override
  Future<void> write(PluginInstallJournalEntry entry) async {
    _validateEntry(entry);
    _transaction(() {
      final rows = _db.select(
        'SELECT * FROM plugin_install_operation WHERE operation_id = ?',
        [entry.operationId],
      );
      if (rows.isEmpty) {
        _db.execute('''
          INSERT INTO plugin_install_operation ($_columns, revision)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ''', _values(entry));
        _insertEvent(entry, 1);
        return;
      }
      final current = Map<String, Object?>.from(rows.first);
      if (current['plugin_id'] != entry.pluginId || current['version'] != entry.version) {
        throw StateError('An operation ID cannot be reused for a different plugin or version.');
      }
      final revision = current['revision']! as int;
      final currentAt = _parseDate(current['updated_at']);
      if (entry.updatedAt.toUtc().isBefore(currentAt)) {
        throw StateError('Journal updates must not move updatedAt backwards.');
      }
      _update(entry, revision + 1);
    });
  }

  void _update(PluginInstallJournalEntry entry, int revision) {
    _db.execute('''
      UPDATE plugin_install_operation SET
        schema_version = ?, plugin_id = ?, version = ?, status = ?, revision = ?,
        updated_at = ?, staging_handle = ?, promoted_path = ?, failure_code = ?,
        content_hash = ?, approved_by = ?, approval_id = ?
      WHERE operation_id = ?
    ''', [
      _schemaVersion, entry.pluginId, entry.version, entry.status.name, revision,
      _date(entry.updatedAt), entry.stagingHandle, entry.promotedPath,
      entry.failureCode, entry.contentHash, entry.approvedBy, entry.approvalId,
      entry.operationId,
    ]);
    _insertEvent(entry, revision);
  }

  static List<Object?> _values(PluginInstallJournalEntry entry) => [
    entry.operationId, _schemaVersion, entry.pluginId, entry.version,
    entry.status.name, _date(entry.updatedAt), entry.stagingHandle,
    entry.promotedPath, entry.failureCode, entry.contentHash,
    entry.approvedBy, entry.approvalId,
  ];

  static void _validateEntry(PluginInstallJournalEntry entry) {
    for (final value in [entry.operationId, entry.pluginId, entry.version]) {
      if (value.trim().isEmpty) throw ArgumentError('Journal identity fields must not be empty.');
    }
    if (entry.approvalId != null && entry.approvedBy == null) {
      throw ArgumentError('An approval ID requires an operator identity.');
    }
    if (entry.approvalId != null && entry.approvalId!.trim().isEmpty) {
      throw ArgumentError('Approval ID must not be empty.');
    }
  }

  @override
  Future<List<PluginInstallJournalEntry>> unresolved() async {
    _assertOpen();
    final rows = _db.select('''
      SELECT * FROM plugin_install_operation
      WHERE status NOT IN ('committed', 'rolledBack', 'failed')
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
      if (rows.isEmpty) return false;
      final current = Map<String, Object?>.from(rows.first);
      if (current['status'] != expectedStatus.name ||
          current['updated_at'] != _date(expectedUpdatedAt) ||
          current['plugin_id'] != replacement.pluginId ||
          current['version'] != replacement.version) {
        return false;
      }
      _update(replacement, (current['revision']! as int) + 1);
      return true;
    });
  }
}

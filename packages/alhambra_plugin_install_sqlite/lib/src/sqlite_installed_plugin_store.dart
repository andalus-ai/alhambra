import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// Durable installed-plugin metadata store with operation-scoped fencing.
///
/// Installed rows retain the operation ID that created them. Fencing tokens
/// are stored separately and advance monotonically per operation. This lets a
/// recovery worker with a newer token remove the record created by the same
/// interrupted operation, without allowing it to remove another operation's
/// record.
final class SqliteInstalledPluginStore
    implements FencedTransactionalInstalledPluginStore {
  final sq.Database _db;
  bool _closed = false;

  SqliteInstalledPluginStore(String path) : _db = sq.sqlite3.open(path) {
    _configure(path);
    _migrate();
  }

  SqliteInstalledPluginStore.memory() : _db = sq.sqlite3.openInMemory() {
    _configure(':memory:');
    _migrate();
  }

  void _configure(String path) {
    _db.execute('PRAGMA busy_timeout = 5000');
    if (path != ':memory:') _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = FULL');
  }

  void close() {
    if (_closed) return;
    _db.dispose();
    _closed = true;
  }

  void _assertOpen() {
    if (_closed) throw StateError('SQLite installed-plugin store is closed.');
  }

  void _migrate() {
    _transaction(() {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_installed_plugin (
          plugin_id TEXT PRIMARY KEY,
          version TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          publisher_id TEXT,
          publisher_name TEXT,
          publisher_website TEXT,
          installed_at TEXT NOT NULL,
          install_path TEXT NOT NULL,
          install_operation_id TEXT
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS alhambra_installed_plugin_fence (
          operation_id TEXT PRIMARY KEY,
          highest_token INTEGER NOT NULL CHECK (highest_token >= 1)
        )
      ''');
      _db.execute('''
        CREATE INDEX IF NOT EXISTS idx_alhambra_installed_plugin_operation
        ON alhambra_installed_plugin(install_operation_id)
      ''');
    });
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

  static String _date(DateTime value) => value.toUtc().toIso8601String();

  static InstalledPluginRecord _record(Map<String, Object?> row) {
    final publisherId = row['publisher_id'] as String?;
    final publisher = publisherId == null
        ? null
        : PluginPublisher(
            id: publisherId,
            name: row['publisher_name']! as String,
            website: row['publisher_website'] as String?,
          );
    return InstalledPluginRecord(
      id: row['plugin_id']! as String,
      version: SemanticVersion.parse(row['version']! as String),
      contentHash: row['content_hash']! as String,
      publisher: publisher,
      installedAt: DateTime.parse(row['installed_at']! as String).toUtc(),
      installPath: row['install_path']! as String,
    );
  }

  static void _validateRecord(InstalledPluginRecord plugin) {
    if (plugin.id.trim().isEmpty ||
        plugin.contentHash.trim().isEmpty ||
        plugin.installPath.trim().isEmpty) {
      throw ArgumentError('Installed plugin identity, hash and path must not be empty.');
    }
    final publisher = plugin.publisher;
    if (publisher != null &&
        (publisher.id.trim().isEmpty || publisher.name.trim().isEmpty)) {
      throw ArgumentError('Publisher identity and name must not be empty.');
    }
  }

  static List<Object?> _values(
    InstalledPluginRecord plugin, {
    required String? operationId,
  }) => [
        plugin.id,
        plugin.version.toString(),
        plugin.contentHash,
        plugin.publisher?.id,
        plugin.publisher?.name,
        plugin.publisher?.website,
        _date(plugin.installedAt),
        plugin.installPath,
        operationId,
      ];

  static const String _columns = '''
    plugin_id, version, content_hash, publisher_id, publisher_name,
    publisher_website, installed_at, install_path, install_operation_id
  ''';

  void _insert(
    InstalledPluginRecord plugin, {
    required String? operationId,
  }) {
    _db.execute(
      'INSERT INTO alhambra_installed_plugin ($_columns) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      _values(plugin, operationId: operationId),
    );
  }

  void _update(InstalledPluginRecord plugin) {
    _db.execute('''
      UPDATE alhambra_installed_plugin SET
        version = ?, content_hash = ?, publisher_id = ?, publisher_name = ?,
        publisher_website = ?, installed_at = ?, install_path = ?
      WHERE plugin_id = ?
    ''', [
      plugin.version.toString(),
      plugin.contentHash,
      plugin.publisher?.id,
      plugin.publisher?.name,
      plugin.publisher?.website,
      _date(plugin.installedAt),
      plugin.installPath,
      plugin.id,
    ]);
  }

  bool _matchesRecord(
    Map<String, Object?> row,
    InstalledPluginRecord plugin,
  ) {
    return row['plugin_id'] == plugin.id &&
        row['version'] == plugin.version.toString() &&
        row['content_hash'] == plugin.contentHash &&
        row['publisher_id'] == plugin.publisher?.id &&
        row['publisher_name'] == plugin.publisher?.name &&
        row['publisher_website'] == plugin.publisher?.website &&
        row['installed_at'] == _date(plugin.installedAt) &&
        row['install_path'] == plugin.installPath;
  }

  void _assertAcceptedFence(String operationId, int fencingToken) {
    final rows = _db.select(
      'SELECT highest_token FROM alhambra_installed_plugin_fence WHERE operation_id = ?',
      [operationId],
    );
    if (rows.isEmpty || rows.first['highest_token'] != fencingToken) {
      throw StateError('Installed-plugin write rejected because its fencing token is stale or unregistered.');
    }
  }

  @override
  Future<List<InstalledPluginRecord>> all() async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM alhambra_installed_plugin ORDER BY plugin_id',
    );
    return List.unmodifiable(rows.map(
      (row) => _record(Map<String, Object?>.from(row)),
    ));
  }

  @override
  Future<InstalledPluginRecord?> find(String pluginId) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM alhambra_installed_plugin WHERE plugin_id = ?',
      [pluginId],
    );
    return rows.isEmpty
        ? null
        : _record(Map<String, Object?>.from(rows.first));
  }

  @override
  Future<void> save(InstalledPluginRecord plugin) async {
    _validateRecord(plugin);
    _transaction(() {
      final rows = _db.select(
        'SELECT install_operation_id FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      if (rows.isEmpty) {
        _insert(plugin, operationId: null);
        return;
      }
      if (rows.first['install_operation_id'] != null) {
        throw StateError(
          'An operation-owned installed record must be changed through its fenced operation.',
        );
      }
      _update(plugin);
    });
  }

  @override
  Future<void> remove(String pluginId) async {
    _transaction(() {
      final rows = _db.select(
        'SELECT install_operation_id FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [pluginId],
      );
      if (rows.isEmpty) return;
      if (rows.first['install_operation_id'] != null) {
        throw StateError(
          'An operation-owned installed record must be removed through its fenced operation.',
        );
      }
      _db.execute(
        'DELETE FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [pluginId],
      );
    });
  }

  @override
  Future<bool> createIfAbsent(InstalledPluginRecord plugin) async {
    _validateRecord(plugin);
    return _transaction(() {
      final rows = _db.select(
        'SELECT 1 FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      if (rows.isNotEmpty) return false;
      _insert(plugin, operationId: null);
      return true;
    });
  }

  @override
  Future<bool> removeIfMatches(InstalledPluginRecord plugin) async {
    _validateRecord(plugin);
    return _transaction(() {
      final rows = _db.select(
        'SELECT * FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      if (rows.isEmpty) return false;
      final current = Map<String, Object?>.from(rows.first);
      if (current['install_operation_id'] != null ||
          !_matchesRecord(current, plugin)) {
        return false;
      }
      _db.execute(
        'DELETE FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      return true;
    });
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
        'SELECT highest_token FROM alhambra_installed_plugin_fence WHERE operation_id = ?',
        [operationId],
      );
      if (rows.isEmpty) {
        _db.execute(
          'INSERT INTO alhambra_installed_plugin_fence(operation_id, highest_token) VALUES (?, ?)',
          [operationId, fencingToken],
        );
        return true;
      }
      final highest = rows.first['highest_token']! as int;
      if (fencingToken < highest) return false;
      if (fencingToken == highest) return true;
      _db.execute(
        'UPDATE alhambra_installed_plugin_fence SET highest_token = ? WHERE operation_id = ?',
        [fencingToken, operationId],
      );
      return true;
    });
  }

  @override
  Future<bool> createIfAbsentFenced(
    InstalledPluginRecord plugin, {
    required String operationId,
    required int fencingToken,
  }) async {
    _validateRecord(plugin);
    if (operationId.trim().isEmpty) {
      throw ArgumentError('Operation ID must not be empty.');
    }
    return _transaction(() {
      _assertAcceptedFence(operationId, fencingToken);
      final rows = _db.select(
        'SELECT 1 FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      if (rows.isNotEmpty) return false;
      _insert(plugin, operationId: operationId);
      return true;
    });
  }

  @override
  Future<bool> removeIfMatchesFenced(
    InstalledPluginRecord plugin, {
    required String operationId,
    required int fencingToken,
  }) async {
    _validateRecord(plugin);
    if (operationId.trim().isEmpty) {
      throw ArgumentError('Operation ID must not be empty.');
    }
    return _transaction(() {
      _assertAcceptedFence(operationId, fencingToken);
      final rows = _db.select(
        'SELECT * FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      if (rows.isEmpty) return false;
      final current = Map<String, Object?>.from(rows.first);
      if (current['install_operation_id'] != operationId ||
          !_matchesRecord(current, plugin)) {
        return false;
      }
      _db.execute(
        'DELETE FROM alhambra_installed_plugin WHERE plugin_id = ?',
        [plugin.id],
      );
      return true;
    });
  }
}

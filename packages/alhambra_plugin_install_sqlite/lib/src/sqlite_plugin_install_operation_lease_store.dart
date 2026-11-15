import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Durable SQLite lease store for installer and recovery workers.
///
/// The database preserves the last fencing token even after release or expiry.
/// All ownership transitions use BEGIN IMMEDIATE so independent connections
/// cannot acquire the same operation concurrently. Supply a consistent
/// authoritative [now] value from the host; multi-host deployments should
/// preferably derive it from the database clock.
final class SqlitePluginInstallOperationLeaseStore
    implements PluginInstallOperationLeaseStore {
  final sq.Database _db;
  bool _closed = false;

  SqlitePluginInstallOperationLeaseStore(String path)
      : _db = sq.sqlite3.open(path) {
    _configure(path);
    _migrate();
  }

  SqlitePluginInstallOperationLeaseStore.memory()
      : _db = sq.sqlite3.openInMemory() {
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
    if (_closed) throw StateError('SQLite plugin install lease store is closed.');
  }

  void _migrate() {
    final version = _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version > 1) {
      throw UnsupportedError('Lease schema version $version is newer than this adapter supports.');
    }
    if (version == 0) {
      _transaction(() {
        _db.execute('''
          CREATE TABLE plugin_install_lease (
            operation_id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            fencing_token INTEGER NOT NULL CHECK (fencing_token >= 1),
            acquired_at TEXT NOT NULL,
            expires_at TEXT NOT NULL
          )
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

  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static DateTime _parseDate(Object? value) => DateTime.parse(value! as String).toUtc();

  static PluginInstallOperationLease _lease(Map<String, Object?> row) =>
      PluginInstallOperationLease(
        operationId: row['operation_id']! as String,
        ownerId: row['owner_id']! as String,
        fencingToken: row['fencing_token']! as int,
        acquiredAt: _parseDate(row['acquired_at']),
        expiresAt: _parseDate(row['expires_at']),
      );

  static void _validate(String operationId, String ownerId, Duration duration) {
    if (operationId.trim().isEmpty || ownerId.trim().isEmpty) {
      throw ArgumentError('Operation and owner IDs must not be empty.');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'leaseDuration', 'Must be positive.');
    }
  }

  static bool _matches(
    PluginInstallOperationLease current,
    PluginInstallOperationLease candidate,
  ) =>
      current.operationId == candidate.operationId &&
      current.ownerId == candidate.ownerId &&
      current.fencingToken == candidate.fencingToken;

  @override
  Future<PluginInstallOperationLease?> acquire({
    required String operationId,
    required String ownerId,
    required DateTime now,
    required Duration leaseDuration,
  }) async {
    _validate(operationId, ownerId, leaseDuration);
    final instant = now.toUtc();
    return _transaction(() {
      final rows = _db.select(
        'SELECT * FROM plugin_install_lease WHERE operation_id = ?',
        [operationId],
      );
      if (rows.isNotEmpty) {
        final current = _lease(Map<String, Object?>.from(rows.first));
        if (current.isValidAt(instant)) {
          return current.ownerId == ownerId ? current : null;
        }
        final next = PluginInstallOperationLease(
          operationId: operationId,
          ownerId: ownerId,
          fencingToken: current.fencingToken + 1,
          acquiredAt: instant,
          expiresAt: instant.add(leaseDuration),
        );
        _db.execute('''
          UPDATE plugin_install_lease
          SET owner_id = ?, fencing_token = ?, acquired_at = ?, expires_at = ?
          WHERE operation_id = ?
        ''', [ownerId, next.fencingToken, _date(next.acquiredAt),
          _date(next.expiresAt), operationId]);
        return next;
      }
      final created = PluginInstallOperationLease(
        operationId: operationId,
        ownerId: ownerId,
        fencingToken: 1,
        acquiredAt: instant,
        expiresAt: instant.add(leaseDuration),
      );
      _db.execute('''
        INSERT INTO plugin_install_lease
        (operation_id, owner_id, fencing_token, acquired_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
      ''', [operationId, ownerId, 1, _date(created.acquiredAt), _date(created.expiresAt)]);
      return created;
    });
  }

  @override
  Future<PluginInstallOperationLease?> renew({
    required PluginInstallOperationLease lease,
    required DateTime now,
    required Duration leaseDuration,
  }) async {
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(leaseDuration, 'leaseDuration', 'Must be positive.');
    }
    final instant = now.toUtc();
    return _transaction(() {
      final rows = _db.select(
        'SELECT * FROM plugin_install_lease WHERE operation_id = ?',
        [lease.operationId],
      );
      if (rows.isEmpty) return null;
      final current = _lease(Map<String, Object?>.from(rows.first));
      if (!_matches(current, lease) || !current.isValidAt(instant)) return null;
      final renewed = PluginInstallOperationLease(
        operationId: current.operationId,
        ownerId: current.ownerId,
        fencingToken: current.fencingToken,
        acquiredAt: current.acquiredAt,
        expiresAt: instant.add(leaseDuration),
      );
      _db.execute(
        'UPDATE plugin_install_lease SET expires_at = ? WHERE operation_id = ? AND fencing_token = ?',
        [_date(renewed.expiresAt), lease.operationId, lease.fencingToken],
      );
      return renewed;
    });
  }

  @override
  Future<bool> release({
    required PluginInstallOperationLease lease,
    required DateTime now,
  }) async =>
      _transaction(() {
        final rows = _db.select(
          'SELECT * FROM plugin_install_lease WHERE operation_id = ?',
          [lease.operationId],
        );
        if (rows.isEmpty) return false;
        final current = _lease(Map<String, Object?>.from(rows.first));
        if (!_matches(current, lease)) return false;
        _db.execute(
          'UPDATE plugin_install_lease SET expires_at = ? WHERE operation_id = ? AND fencing_token = ?',
          [_date(now), lease.operationId, lease.fencingToken],
        );
        return true;
      });

  @override
  Future<bool> isCurrent({
    required PluginInstallOperationLease lease,
    required DateTime now,
  }) async {
    _assertOpen();
    final rows = _db.select(
      'SELECT * FROM plugin_install_lease WHERE operation_id = ?',
      [lease.operationId],
    );
    if (rows.isEmpty) return false;
    final current = _lease(Map<String, Object?>.from(rows.first));
    return _matches(current, lease) && current.isValidAt(now.toUtc());
  }
}

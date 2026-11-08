import 'package:alhambra_data/alhambra_data.dart' as contracts;
import 'package:sqlite3/sqlite3.dart' as sq;

/// SQLite implementation of [contracts.Database] and [contracts.DatabaseTransaction].
///
/// Wraps the synchronous `sqlite3` package in the async [contracts.Database] interface.
/// Named parameters (`:name`) in SQL strings are converted to positional `?`
/// placeholders — matching the order they appear in the [parameters] map.
///
/// Usage:
/// ```dart
/// final db = Sqlite3Database.memory();   // in-memory for tests
/// await db.open();
/// await db.execute('CREATE TABLE items (id TEXT PRIMARY KEY, value TEXT)');
/// await db.execute('INSERT INTO items VALUES (:id, :value)',
///   parameters: {'id': '1', 'value': 'hello'});
/// final rows = await db.query('SELECT * FROM items WHERE id = :id',
///   parameters: {'id': '1'});
/// await db.close();
/// ```
final class Sqlite3Database
    implements contracts.Database, contracts.DatabaseTransaction {
  final String _path;
  sq.Database? _db;

  /// Opens (or creates) a SQLite database at [path].
  Sqlite3Database(this._path);

  /// Opens an ephemeral in-memory database — ideal for tests.
  Sqlite3Database.memory() : _path = ':memory:';

  bool get isOpen => _db != null;

  @override
  Future<void> open() async {
    if (_path == ':memory:') {
      _db = sq.sqlite3.openInMemory();
    } else {
      _db = sq.sqlite3.open(_path);
    }
    // Enable WAL mode for better concurrency on file DBs
    if (_path != ':memory:') {
      _db!.execute('PRAGMA journal_mode=WAL');
    }
    _db!.execute('PRAGMA foreign_keys=ON');
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String query, {
    Map<String, Object?> parameters = const {},
  }) async {
    _assertOpen();
    final (sql, args) = _prepare(query, parameters);
    final result = _db!.select(sql, args);
    return result.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, Object?> parameters = const {},
  }) async {
    _assertOpen();
    final (sql, args) = _prepare(query, parameters);
    if (args.isEmpty) {
      _db!.execute(sql);
    } else {
      final stmt = _db!.prepare(sql);
      try {
        stmt.execute(args);
      } finally {
        stmt.dispose();
      }
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(contracts.DatabaseTransaction tx) action,
  ) async {
    _assertOpen();
    _db!.execute('BEGIN');
    try {
      final result = await action(this);
      _db!.execute('COMMIT');
      return result;
    } catch (e) {
      _db!.execute('ROLLBACK');
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertOpen() {
    if (_db == null) throw StateError('Database is not open');
  }

  /// Replaces `:paramName` tokens with `?` and builds a positional arg list.
  static (String sql, List<Object?> args) _prepare(
    String query,
    Map<String, Object?> params,
  ) {
    if (params.isEmpty) return (query, const []);
    final args = <Object?>[];
    final sql = query.replaceAllMapped(
      RegExp(r':(\w+)'),
      (m) {
        args.add(params[m.group(1)]);
        return '?';
      },
    );
    return (sql, args);
  }
}

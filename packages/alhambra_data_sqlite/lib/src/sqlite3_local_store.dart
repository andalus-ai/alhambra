import 'dart:convert';

import 'package:alhambra_data/alhambra_data.dart';

import 'sqlite3_database.dart';

const _kTable = 'local_store';

/// SQLite-backed [LocalStore] implementation.
///
/// Values are JSON-encoded before storage, so any JSON-serialisable Dart
/// type (`String`, `int`, `double`, `bool`, `List`, `Map`) round-trips
/// correctly through [put] → [get].
final class Sqlite3LocalStore implements LocalStore {
  final Sqlite3Database _db;

  Sqlite3LocalStore(this._db);

  /// Creates the backing table if it does not exist.
  Future<void> init() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_kTable (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<T?> get<T>(String key) async {
    final rows = await _db.query(
      'SELECT value FROM $_kTable WHERE key = :key',
      parameters: {'key': key},
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String;
    return jsonDecode(raw) as T?;
  }

  @override
  Future<void> put<T>(String key, T value) async {
    await _db.execute(
      'INSERT OR REPLACE INTO $_kTable (key, value) VALUES (:key, :value)',
      parameters: {'key': key, 'value': jsonEncode(value)},
    );
  }

  @override
  Future<void> delete(String key) async {
    await _db.execute(
      'DELETE FROM $_kTable WHERE key = :key',
      parameters: {'key': key},
    );
  }

  @override
  Future<bool> contains(String key) async {
    final rows = await _db.query(
      'SELECT 1 FROM $_kTable WHERE key = :key',
      parameters: {'key': key},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> clear() async {
    await _db.execute('DELETE FROM $_kTable');
  }
}

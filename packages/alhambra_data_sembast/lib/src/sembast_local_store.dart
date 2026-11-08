import 'dart:convert';

import 'package:alhambra_data/alhambra_data.dart' show LocalStore;
import 'package:sembast/sembast.dart' as sembast;

/// Sembast implementation of [LocalStore].
///
/// Values are serialized with [jsonEncode] before storage and decoded with
/// [jsonDecode] on retrieval, allowing arbitrary JSON-compatible types.
class SembastLocalStore implements LocalStore {
  SembastLocalStore(this._db);

  final sembast.Database _db;
  final sembast.StoreRef<String, String> _store =
      sembast.StoreRef<String, String>('local_store');

  @override
  Future<T?> get<T>(String key) async {
    final raw = await _store.record(key).get(_db);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded as T?;
  }

  @override
  Future<void> put<T>(String key, T value) async {
    await _store.record(key).put(_db, jsonEncode(value));
  }

  @override
  Future<void> delete(String key) => _store.record(key).delete(_db);

  @override
  Future<bool> contains(String key) async =>
      (await _store.record(key).get(_db)) != null;

  @override
  Future<void> clear() => _store.delete(_db);
}

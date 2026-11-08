import 'package:alhambra_data/alhambra_data.dart' show KeyValueStore;
import 'package:sembast/sembast.dart' as sembast;

/// Sembast implementation of [KeyValueStore].
///
/// Uses [sembast.StoreRef.main()] to persist string key→value pairs in a
/// sembast [sembast.Database]. Values are stored as plain Dart strings.
class SembastKeyValueStore implements KeyValueStore {
  SembastKeyValueStore(this._db);

  final sembast.Database _db;
  final sembast.StoreRef<String, String> _store =
      sembast.StoreRef<String, String>.main();

  @override
  Future<String?> read(String key) => _store.record(key).get(_db);

  @override
  Future<void> write(String key, String value) =>
      _store.record(key).put(_db, value);

  @override
  Future<void> remove(String key) => _store.record(key).delete(_db);
}

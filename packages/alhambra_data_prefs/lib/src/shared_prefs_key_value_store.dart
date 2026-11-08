import 'package:shared_preferences/shared_preferences.dart';
import 'package:alhambra_data/alhambra_data.dart';

/// [SharedPreferences]-backed implementation of [KeyValueStore].
///
/// All values are stored as plain strings. The instance must be
/// created via [SharedPrefsKeyValueStore.create()] or by injecting
/// an already-initialised [SharedPreferences] instance.
final class SharedPrefsKeyValueStore implements KeyValueStore {
  final SharedPreferences _prefs;

  /// Constructs from an existing [SharedPreferences] instance.
  const SharedPrefsKeyValueStore(this._prefs);

  /// Factory that initialises [SharedPreferences] and returns a ready instance.
  static Future<SharedPrefsKeyValueStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsKeyValueStore(prefs);
  }

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}

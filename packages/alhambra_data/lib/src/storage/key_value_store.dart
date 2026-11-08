/// Lowest-level key-value persistence contract in the Alhambra data layer.
abstract interface class KeyValueStore {
  /// Reads string value associated with [key], or `null` if not found.
  Future<String?> read(String key);

  /// Writes string [value] for [key].
  Future<void> write(String key, String value);

  /// Removes the entry for [key].
  Future<void> remove(String key);
}

/// In-memory implementation of [KeyValueStore] for testing and transient use.
final class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  /// Clears all entries.
  Future<void> clear() async {
    _data.clear();
  }
}

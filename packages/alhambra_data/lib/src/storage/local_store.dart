/// Serialization contract to decouple domain objects from underlying storage representation.
abstract interface class Serializer<T> {
  String serialize(T value);
  T deserialize(String raw);
}

/// Typed local storage abstraction.
abstract interface class LocalStore {
  /// Retrieves a value by [key].
  Future<T?> get<T>(String key);

  /// Stores a [value] under [key].
  Future<void> put<T>(String key, T value);

  /// Deletes the entry under [key].
  Future<void> delete(String key);

  /// Checks if [key] exists.
  Future<bool> contains(String key);

  /// Clears all entries.
  Future<void> clear();
}

/// In-memory implementation of [LocalStore].
final class InMemoryLocalStore implements LocalStore {
  final Map<String, Object?> _data = {};

  @override
  Future<T?> get<T>(String key) async {
    final val = _data[key];
    if (val == null) return null;
    return val as T;
  }

  @override
  Future<void> put<T>(String key, T value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async {
    return _data.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

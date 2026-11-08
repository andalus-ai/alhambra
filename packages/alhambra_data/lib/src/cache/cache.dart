/// Generalized caching interface.
abstract interface class Cache {
  /// Retrieves a cached value if present and unexpired; returns `null` otherwise.
  Future<T?> get<T>(String key);

  /// Puts a [value] in cache with optional [ttl].
  Future<void> put<T>(
    String key,
    T value, {
    Duration? ttl,
  });

  /// Explicitly removes entry for [key].
  Future<void> remove(String key);

  /// Clears all entries from cache.
  Future<void> clear();
}

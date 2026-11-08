import 'cache.dart';
import 'cache_entry.dart';

/// In-memory cache implementation honoring TTL expiration.
final class MemoryCache implements Cache {
  final Map<String, CacheEntry<Object?>> _store = {};

  @override
  Future<T?> get<T>(String key) async {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  @override
  Future<void> put<T>(
    String key,
    T value, {
    Duration? ttl,
  }) async {
    final now = DateTime.now();
    final entry = CacheEntry<Object?>(
      value: value,
      createdAt: now,
      expiresAt: ttl != null ? now.add(ttl) : null,
    );
    _store[key] = entry;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  /// Returns current count of valid, non-expired entries.
  int get count {
    _cleanupExpired();
    return _store.length;
  }

  void _cleanupExpired() {
    _store.removeWhere((_, entry) => entry.isExpired);
  }
}

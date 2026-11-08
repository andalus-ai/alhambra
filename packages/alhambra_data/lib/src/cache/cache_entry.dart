/// Container for a cached item with creation timestamp and optional TTL expiration.
final class CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const CacheEntry({
    required this.value,
    required this.createdAt,
    this.expiresAt,
  });

  /// Whether this entry has exceeded its time-to-live threshold.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  String toString() =>
      'CacheEntry(value: $value, created: $createdAt, expired: $isExpired)';
}

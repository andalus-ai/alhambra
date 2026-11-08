/// A named feature flag used to enable/disable platform capabilities at runtime.
///
/// Feature flags are **not** authorization: they answer "is this capability enabled?"
/// not "is this actor allowed?". Both must be evaluated independently.
final class FeatureFlag {
  final String key;
  final bool enabled;
  final Map<String, Object?> metadata;

  const FeatureFlag({
    required this.key,
    required this.enabled,
    this.metadata = const {},
  });

  @override
  String toString() => 'FeatureFlag($key: $enabled)';
}

/// Platform feature flag service.
abstract interface class FeatureFlagService {
  /// Returns true if [key] is enabled for the optional [userId]/[organizationId] context.
  Future<bool> isEnabled(
    String key, {
    String? userId,
    String? organizationId,
  });

  /// Returns the full [FeatureFlag] for [key], or `null` if unknown.
  Future<FeatureFlag?> get(String key);
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// In-memory [FeatureFlagService] backed by a simple flag map.
final class InMemoryFeatureFlagService implements FeatureFlagService {
  final Map<String, FeatureFlag> _flags;

  InMemoryFeatureFlagService(Map<String, bool> flags)
      : _flags = {
          for (final e in flags.entries)
            e.key: FeatureFlag(key: e.key, enabled: e.value),
        };

  @override
  Future<bool> isEnabled(
    String key, {
    String? userId,
    String? organizationId,
  }) async =>
      _flags[key]?.enabled ?? false;

  @override
  Future<FeatureFlag?> get(String key) async => _flags[key];
}

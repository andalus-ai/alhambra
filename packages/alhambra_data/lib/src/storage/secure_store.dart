/// Secure key-value storage contract for secrets, auth tokens, and sensitive credentials.
abstract interface class SecureStore {
  /// Reads a sensitive string value for [key], or `null` if not found.
  Future<String?> read(String key);

  /// Writes a sensitive string [value] for [key].
  Future<void> write(String key, String value);

  /// Removes the sensitive entry for [key].
  Future<void> remove(String key);
}

/// In-memory implementation of [SecureStore] for testing environments.
final class InMemorySecureStore implements SecureStore {
  final Map<String, String> _secrets = {};

  @override
  Future<String?> read(String key) async => _secrets[key];

  @override
  Future<void> write(String key, String value) async {
    _secrets[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _secrets.remove(key);
  }

  /// Clears all stored secrets.
  Future<void> clear() async {
    _secrets.clear();
  }
}

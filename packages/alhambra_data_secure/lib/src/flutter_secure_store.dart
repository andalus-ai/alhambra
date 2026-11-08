import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:alhambra_data/alhambra_data.dart';

/// [FlutterSecureStorage]-backed implementation of [SecureStore].
///
/// Uses platform keychain / keystore under the hood via
/// [flutter_secure_storage]. Can be constructed with a custom
/// [FlutterSecureStorage] instance for testing/mocking.
final class FlutterSecureStoreAdapter implements SecureStore {
  final FlutterSecureStorage _storage;

  /// Creates an adapter with optional custom [FlutterSecureStorage] instance.
  const FlutterSecureStoreAdapter(
      [this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}

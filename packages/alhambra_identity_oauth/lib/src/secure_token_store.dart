import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_network/alhambra_network.dart';

import 'token_keys.dart';

/// Persists and retrieves [AuthToken] from [SecureStore].
///
/// Keys are namespaced under `alhambra.auth.*` so they don't collide with
/// other app secrets. Expiry is stored as an ISO-8601 string.
final class SecureTokenStore {
  final SecureStore _store;

  const SecureTokenStore(this._store);

  /// Saves [token] and an optional [refreshToken] value.
  Future<void> save(AuthToken token, {String? refreshToken}) async {
    await _store.write(TokenKeys.accessToken, token.value);
    await _store.write(TokenKeys.tokenType, token.tokenType);
    if (token.expiresAt != null) {
      await _store.write(
          TokenKeys.expiresAt, token.expiresAt!.toIso8601String());
    }
    if (refreshToken != null) {
      await _store.write(TokenKeys.refreshToken, refreshToken);
    }
  }

  /// Reads the persisted [AuthToken], or `null` if none is stored.
  Future<AuthToken?> load() async {
    final value = await _store.read(TokenKeys.accessToken);
    if (value == null) return null;

    final tokenType =
        await _store.read(TokenKeys.tokenType) ?? 'Bearer';
    final expiresAtStr = await _store.read(TokenKeys.expiresAt);
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

    return AuthToken(
      value: value,
      tokenType: tokenType,
      expiresAt: expiresAt,
    );
  }

  /// Reads the stored refresh token value, or `null`.
  Future<String?> loadRefreshToken() async =>
      _store.read(TokenKeys.refreshToken);

  /// Clears all stored token data (logout).
  Future<void> clear() async {
    await _store.remove(TokenKeys.accessToken);
    await _store.remove(TokenKeys.refreshToken);
    await _store.remove(TokenKeys.tokenType);
    await _store.remove(TokenKeys.expiresAt);
    await _store.remove(TokenKeys.organizationId);
  }

  /// Persists the currently active organization id.
  Future<void> saveOrganizationId(String orgId) =>
      _store.write(TokenKeys.organizationId, orgId);

  /// Reads the currently active organization id.
  Future<String?> loadOrganizationId() =>
      _store.read(TokenKeys.organizationId);
}

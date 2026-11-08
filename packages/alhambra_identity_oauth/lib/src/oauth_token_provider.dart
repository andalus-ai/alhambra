import 'dart:async';

import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_network/alhambra_network.dart';
import 'package:meta/meta.dart';

import 'secure_token_store.dart';

/// Callback used to perform the actual token refresh network call.
///
/// Receives the current refresh token string.
/// Returns a new [AuthToken] + optional new refresh token on success,
/// or `null` if the session cannot be renewed (e.g. refresh token expired).
typedef TokenRefreshCallback = Future<({AuthToken token, String? refreshToken})?>
    Function(String refreshToken);

/// Auth state broadcast by [OAuthTokenProvider].
enum AuthState {
  /// User is authenticated with a valid (non-expired) token.
  authenticated,

  /// User is authenticated but token needs a refresh attempt.
  tokenExpired,

  /// Refresh failed — user must re-authenticate.
  unauthenticated,
}

/// [AuthTokenProvider] backed by [SecureStore] + automatic token refresh.
///
/// - Stores access + refresh tokens securely via [SecureTokenStore].
/// - On [getToken]: returns stored token if valid; triggers refresh if expired.
/// - On [refreshToken]: calls [onRefresh] callback with the stored refresh
///   token; persists new tokens on success; clears and emits
///   [AuthState.unauthenticated] on failure.
/// - Broadcasts [AuthState] changes via [authStateChanges].
///
/// Usage:
/// ```dart
/// final provider = OAuthTokenProvider(
///   store: SecureTokenStore(secureStore),
///   onRefresh: (refreshToken) async {
///     final resp = await httpClient.post('/auth/refresh',
///         body: {'refresh_token': refreshToken});
///     if (!resp.isSuccess) return null;
///     return (
///       token: AuthToken(value: resp.data['access_token'], ...),
///       refreshToken: resp.data['refresh_token'],
///     );
///   },
/// );
/// ```
final class OAuthTokenProvider implements AuthTokenProvider {
  final SecureTokenStore _store;
  final TokenRefreshCallback _onRefresh;

  final StreamController<AuthState> _stateController =
      StreamController<AuthState>.broadcast();

  bool _isRefreshing = false;

  OAuthTokenProvider({
    required SecureTokenStore store,
    required TokenRefreshCallback onRefresh,
  })  : _store = store,
        _onRefresh = onRefresh;

  /// Stream of auth state changes. Listen to update UI (login/logout/expired).
  Stream<AuthState> get authStateChanges => _stateController.stream;

  @override
  Future<AuthToken?> getToken() async {
    final token = await _store.load();
    if (token == null) {
      _emit(AuthState.unauthenticated);
      return null;
    }
    if (token.isExpired) {
      _emit(AuthState.tokenExpired);
      return refreshToken();
    }
    _emit(AuthState.authenticated);
    return token;
  }

  @override
  Future<AuthToken?> refreshToken() async {
    if (_isRefreshing) {
      // Prevent concurrent refresh loops
      final token = await _store.load();
      return (token != null && !token.isExpired) ? token : null;
    }

    _isRefreshing = true;
    try {
      final refreshTokenValue = await _store.loadRefreshToken();
      if (refreshTokenValue == null) {
        await _clearAndEmitUnauthenticated();
        return null;
      }

      final result = await _onRefresh(refreshTokenValue);
      if (result == null) {
        await _clearAndEmitUnauthenticated();
        return null;
      }

      await _store.save(result.token, refreshToken: result.refreshToken);
      _emit(AuthState.authenticated);
      return result.token;
    } catch (_) {
      await _clearAndEmitUnauthenticated();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manually saves tokens after a successful login flow.
  Future<void> setTokens(AuthToken token, {String? refreshToken}) async {
    await _store.save(token, refreshToken: refreshToken);
    _emit(AuthState.authenticated);
  }

  /// Clears all tokens (logout).
  Future<void> logout() async {
    await _store.clear();
    _emit(AuthState.unauthenticated);
  }

  /// Returns `true` if a non-expired access token is currently stored.
  Future<bool> get isAuthenticated async {
    final token = await _store.load();
    return token != null && !token.isExpired;
  }

  Future<void> _clearAndEmitUnauthenticated() async {
    await _store.clear();
    _emit(AuthState.unauthenticated);
  }

  void _emit(AuthState state) {
    if (!_stateController.isClosed) _stateController.add(state);
  }

  @visibleForTesting
  void dispose() => _stateController.close();
}

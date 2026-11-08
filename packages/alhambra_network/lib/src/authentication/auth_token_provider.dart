import 'auth_token.dart';

/// Contract for supplying the current auth token to the network layer.
///
/// Implementations may read from secure storage, manage refresh flows,
/// or delegate to an identity/session provider.
abstract interface class AuthTokenProvider {
  /// Returns the current auth token, or `null` if the user is not authenticated.
  Future<AuthToken?> getToken();

  /// Called when the network layer receives a 401 response; allows token refresh.
  Future<AuthToken?> refreshToken();
}

/// Static token provider for testing and simple configurations.
final class StaticAuthTokenProvider implements AuthTokenProvider {
  final AuthToken? _token;

  const StaticAuthTokenProvider(this._token);

  @override
  Future<AuthToken?> getToken() async => _token;

  @override
  Future<AuthToken?> refreshToken() async => _token;
}

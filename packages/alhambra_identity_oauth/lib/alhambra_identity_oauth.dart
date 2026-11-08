/// alhambra_identity_oauth
///
/// OAuth2 / token-based [AuthTokenProvider] implementation.
///
/// Wires [SecureStore] from `alhambra_data` with [AuthTokenProvider] from
/// `alhambra_network` to provide automatic token refresh, secure persistence,
/// and auth-state observability.
///
/// Bootstrap:
/// ```dart
/// final provider = OAuthTokenProvider(
///   store: SecureTokenStore(registry.get<SecureStore>()),
///   onRefresh: (rt) => registry.get<NetworkClient>().post('/auth/refresh',
///     body: {'refresh_token': rt},
///     decoder: (b) => _parseTokenResponse(b),
///   ),
/// );
/// registry.register<AuthTokenProvider>(provider);
/// ```
library alhambra_identity_oauth;

export 'src/token_keys.dart';
export 'src/secure_token_store.dart';
export 'src/oauth_token_provider.dart';

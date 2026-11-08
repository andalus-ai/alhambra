/// Token storage key constants used by [SecureTokenStore].
abstract final class TokenKeys {
  static const String accessToken = 'alhambra.auth.access_token';
  static const String refreshToken = 'alhambra.auth.refresh_token';
  static const String tokenType = 'alhambra.auth.token_type';
  static const String expiresAt = 'alhambra.auth.expires_at';
  static const String organizationId = 'alhambra.auth.organization_id';
}

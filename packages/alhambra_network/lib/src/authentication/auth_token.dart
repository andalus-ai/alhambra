/// An immutable auth token value with type and optional expiry.
final class AuthToken {
  final String value;
  final String tokenType;
  final DateTime? expiresAt;

  const AuthToken({
    required this.value,
    this.tokenType = 'Bearer',
    this.expiresAt,
  });

  /// True when token has a known expiry and has passed it.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Authorization header value: `Bearer <token>`.
  String get authorizationHeaderValue => '$tokenType $value';

  @override
  String toString() =>
      'AuthToken(type: $tokenType, expired: $isExpired)';
}

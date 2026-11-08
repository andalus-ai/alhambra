/// Well-known network error codes for consistent error semantics across Alhambra applications.
final class NetworkErrorCode {
  static const String unavailable = 'network.unavailable';
  static const String timeout = 'network.timeout';
  static const String unauthorized = 'network.unauthorized';
  static const String forbidden = 'network.forbidden';
  static const String notFound = 'network.not_found';
  static const String rateLimited = 'network.rate_limited';
  static const String server = 'network.server';
  static const String invalidResponse = 'network.invalid_response';
  static const String cancelled = 'network.cancelled';

  const NetworkErrorCode._();
}

/// Exception thrown when a network call fails.
final class NetworkException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Object? cause;

  const NetworkException({
    required this.code,
    required this.message,
    this.statusCode,
    this.cause,
  });

  @override
  String toString() => 'NetworkException[$code]: $message (HTTP $statusCode)';
}

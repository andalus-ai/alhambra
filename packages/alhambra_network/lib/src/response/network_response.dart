/// Generic network response wrapper.
final class NetworkResponse<T> {
  final int statusCode;
  final T? data;
  final Map<String, String> headers;

  const NetworkResponse({
    required this.statusCode,
    this.data,
    this.headers = const {},
  });

  /// 2xx success.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 4xx client-side error.
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// 5xx server-side error.
  bool get isServerError => statusCode >= 500;

  /// True when [statusCode] is 401 Unauthorized.
  bool get isUnauthorized => statusCode == 401;

  /// True when [statusCode] is 429 Rate Limited.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'NetworkResponse($statusCode, data: $data)';
}

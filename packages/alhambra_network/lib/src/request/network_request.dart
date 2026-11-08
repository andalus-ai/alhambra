import 'request_method.dart';

/// Transport-neutral HTTP request value object.
final class NetworkRequest {
  final RequestMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, Object?> query;
  final Object? body;
  final Duration? timeout;
  final String? idempotencyKey;

  const NetworkRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.query = const {},
    this.body,
    this.timeout,
    this.idempotencyKey,
  });

  NetworkRequest copyWith({
    RequestMethod? method,
    String? path,
    Map<String, String>? headers,
    Map<String, Object?>? query,
    Object? body,
    Duration? timeout,
    String? idempotencyKey,
  }) {
    return NetworkRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      query: query ?? this.query,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  String toString() =>
      'NetworkRequest(${method.name.toUpperCase()} $path, idempotencyKey: $idempotencyKey)';
}

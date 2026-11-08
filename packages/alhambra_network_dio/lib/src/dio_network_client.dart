import 'dart:convert';

import 'package:alhambra_network/alhambra_network.dart';
import 'package:dio/dio.dart';

/// [NetworkClient] implementation backed by [Dio].
///
/// Features:
/// - Configurable via [NetworkClientConfig] (base URL, timeouts, interceptors)
/// - Idempotency-Key header injected when [NetworkRequest.idempotencyKey] is set
/// - Maps DioException types to appropriate HTTP status codes
/// - Applies [NetworkInterceptor] chain for request/response/error hooks
/// - Applies [RetryPolicy] for transient failures
///
/// Usage:
/// ```dart
/// final client = DioNetworkClient(NetworkClientConfig(
///   baseUri: Uri.parse('https://api.example.com'),
/// ));
/// final resp = await client.get<Map<String, dynamic>>(
///   '/workspaces',
///   decoder: (b) => (b as Map).cast<String, dynamic>(),
/// );
/// ```
///
/// In tests, inject a mock adapter:
/// ```dart
/// (client as DioNetworkClient).dio.httpClientAdapter = _MockAdapter();
/// ```
final class DioNetworkClient implements NetworkClient {
  final NetworkClientConfig _config;
  late final Dio _dio;

  DioNetworkClient(NetworkClientConfig config) : _config = config {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUri.toString(),
        connectTimeout: config.timeoutPolicy.connect,
        receiveTimeout: config.timeoutPolicy.receive,
        sendTimeout: config.timeoutPolicy.request,
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  /// Exposes the underlying [Dio] instance for test adapter injection.
  Dio get dio => _dio;

  @override
  Future<NetworkResponse<T>> send<T>(
    NetworkRequest request, {
    T Function(Object? body)? decoder,
  }) async {
    // Apply request interceptors
    var req = request;
    for (final interceptor in _config.interceptors) {
      req = await interceptor.onRequest(req);
    }

    final retryPolicy = _config.retryPolicy;
    int attempt = 0;

    while (true) {
      try {
        final resp = await _dispatch<T>(req, decoder);

        // Apply response interceptors
        NetworkResponse<Object?> raw = NetworkResponse<Object?>(
            statusCode: resp.statusCode, data: resp.data, headers: resp.headers);
        for (final interceptor in _config.interceptors.reversed) {
          raw = await interceptor.onResponse(raw);
        }
        final typed = NetworkResponse<T>(
            statusCode: raw.statusCode,
            data: raw.data as T?,
            headers: raw.headers);

        if (retryPolicy != null &&
            retryPolicy.shouldRetry(
                attempt: attempt,
                error: 'non-retryable response',
                statusCode: typed.statusCode)) {
          await Future<void>.delayed(retryPolicy.delay(attempt: attempt));
          attempt++;
          continue;
        }
        return typed;
      } on DioException catch (e) {
        final status = _mapDioError(e);
        final errResp = NetworkResponse<T>(statusCode: status);

        if (retryPolicy != null &&
            retryPolicy.shouldRetry(
                attempt: attempt, error: e, statusCode: status)) {
          await Future<void>.delayed(retryPolicy.delay(attempt: attempt));
          attempt++;
          continue;
        }

        // Run error interceptors
        Object rethrowable = e;
        for (final interceptor in _config.interceptors.reversed) {
          try {
            await interceptor.onError(rethrowable);
            break;
          } catch (inner) {
            rethrowable = inner;
          }
        }
        return errResp;
      }
    }
  }

  Future<NetworkResponse<T>> _dispatch<T>(
    NetworkRequest req,
    T Function(Object? body)? decoder,
  ) async {
    final headers = Map<String, String>.from(req.headers);
    if (req.idempotencyKey != null) {
      headers['Idempotency-Key'] = req.idempotencyKey!;
    }

    Object? body = req.body;
    if (body != null && body is! String && body is! List<int>) {
      body = jsonEncode(body);
      headers['Content-Type'] = 'application/json';
    }

    final response = await _dio.request<Object?>(
      req.path,
      data: body,
      queryParameters: req.query.isEmpty ? null : req.query,
      options: Options(
        method: req.method.name.toUpperCase(),
        headers: headers,
        sendTimeout: req.timeout,
        receiveTimeout: req.timeout,
      ),
    );

    final data = decoder != null ? decoder(response.data) : response.data as T?;
    return NetworkResponse<T>(
      statusCode: response.statusCode ?? 200,
      data: data,
      headers: _flatHeaders(response.headers.map),
    );
  }

  static int _mapDioError(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          408,
        DioExceptionType.connectionError => 503,
        DioExceptionType.badResponse => e.response?.statusCode ?? 500,
        DioExceptionType.cancel => 499,
        _ => 503,
      };

  static Map<String, String> _flatHeaders(Map<String, List<String>> h) => {
        for (final e in h.entries) e.key.toLowerCase(): e.value.join(', '),
      };

  // ── Convenience methods ──────────────────────────────────────────────────

  @override
  Future<NetworkResponse<T>> get<T>(String path,
          {Map<String, String>? headers,
          Map<String, Object?>? query,
          T Function(Object?)? decoder}) =>
      send(
          NetworkRequest(
              method: RequestMethod.get,
              path: path,
              headers: headers ?? const {},
              query: query ?? const {}),
          decoder: decoder);

  @override
  Future<NetworkResponse<T>> post<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          T Function(Object?)? decoder}) =>
      send(
          NetworkRequest(
              method: RequestMethod.post,
              path: path,
              body: body,
              headers: headers ?? const {}),
          decoder: decoder);

  @override
  Future<NetworkResponse<T>> put<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          T Function(Object?)? decoder}) =>
      send(
          NetworkRequest(
              method: RequestMethod.put,
              path: path,
              body: body,
              headers: headers ?? const {}),
          decoder: decoder);

  @override
  Future<NetworkResponse<T>> patch<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          T Function(Object?)? decoder}) =>
      send(
          NetworkRequest(
              method: RequestMethod.patch,
              path: path,
              body: body,
              headers: headers ?? const {}),
          decoder: decoder);

  @override
  Future<NetworkResponse<T>> delete<T>(String path,
          {Map<String, String>? headers,
          T Function(Object?)? decoder}) =>
      send(
          NetworkRequest(
              method: RequestMethod.delete,
              path: path,
              headers: headers ?? const {}),
          decoder: decoder);
}

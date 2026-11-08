import '../interceptor/network_interceptor.dart';
import '../request/network_request.dart';
import '../response/network_response.dart';
import '../retry/retry_policy.dart';
import '../timeout/timeout_policy.dart';

/// Core transport abstraction. Domain-agnostic; knows nothing about workspaces,
/// intelligence, or any Economic concept.
abstract interface class NetworkClient {
  Future<NetworkResponse<T>> send<T>(
    NetworkRequest request, {
    T Function(Object? body)? decoder,
  });

  Future<NetworkResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, Object?>? query,
    T Function(Object? body)? decoder,
  });

  Future<NetworkResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  });

  Future<NetworkResponse<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  });

  Future<NetworkResponse<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  });

  Future<NetworkResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  });
}

/// Configuration bundle for [NetworkClient] construction.
final class NetworkClientConfig {
  final Uri baseUri;
  final TimeoutPolicy timeoutPolicy;
  final RetryPolicy? retryPolicy;
  final List<NetworkInterceptor> interceptors;

  const NetworkClientConfig({
    required this.baseUri,
    this.timeoutPolicy = const TimeoutPolicy(),
    this.retryPolicy,
    this.interceptors = const [],
  });
}

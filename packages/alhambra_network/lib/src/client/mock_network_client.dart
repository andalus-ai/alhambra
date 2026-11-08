import '../request/network_request.dart';
import '../request/request_method.dart';
import '../response/network_response.dart';
import 'network_client.dart';

/// Stub transport function — receive a request, return a canned response.
typedef MockTransport = Future<NetworkResponse<Object?>> Function(
    NetworkRequest request);

/// In-process [NetworkClient] implementation for tests and local stubs.
/// Applies the interceptor chain, retry policy, and optional timeout.
final class MockNetworkClient implements NetworkClient {
  final NetworkClientConfig config;
  final MockTransport transport;

  const MockNetworkClient({
    required this.config,
    required this.transport,
  });

  // ----- Method shortcuts ------------------------------------------------

  @override
  Future<NetworkResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, Object?>? query,
    T Function(Object? body)? decoder,
  }) =>
      send(
        NetworkRequest(
          method: RequestMethod.get,
          path: path,
          headers: headers ?? const {},
          query: query ?? const {},
        ),
        decoder: decoder,
      );

  @override
  Future<NetworkResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  }) =>
      send(
        NetworkRequest(
          method: RequestMethod.post,
          path: path,
          body: body,
          headers: headers ?? const {},
        ),
        decoder: decoder,
      );

  @override
  Future<NetworkResponse<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  }) =>
      send(
        NetworkRequest(
          method: RequestMethod.put,
          path: path,
          body: body,
          headers: headers ?? const {},
        ),
        decoder: decoder,
      );

  @override
  Future<NetworkResponse<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  }) =>
      send(
        NetworkRequest(
          method: RequestMethod.patch,
          path: path,
          body: body,
          headers: headers ?? const {},
        ),
        decoder: decoder,
      );

  @override
  Future<NetworkResponse<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    T Function(Object? body)? decoder,
  }) =>
      send(
        NetworkRequest(
          method: RequestMethod.delete,
          path: path,
          headers: headers ?? const {},
        ),
        decoder: decoder,
      );

  // ----- Core dispatch ---------------------------------------------------

  @override
  Future<NetworkResponse<T>> send<T>(
    NetworkRequest request, {
    T Function(Object? body)? decoder,
  }) async {
    final interceptors = config.interceptors;
    final retryPolicy = config.retryPolicy;

    // Apply request interceptors in order
    var mutatedRequest = request;
    for (final interceptor in interceptors) {
      mutatedRequest = await interceptor.onRequest(mutatedRequest);
    }

    int attempt = 0;
    while (true) {
      try {
        // Honour per-request or policy timeout
        final timeoutDuration =
            mutatedRequest.timeout ?? config.timeoutPolicy.request;

        NetworkResponse<Object?> rawResponse;
        rawResponse = await transport(mutatedRequest)
            .timeout(timeoutDuration, onTimeout: () {
          throw TimeoutException(
              'Request timed out after ${timeoutDuration.inSeconds}s');
        });

        // Apply response interceptors in reverse order
        for (final interceptor in interceptors.reversed) {
          rawResponse = await interceptor.onResponse(rawResponse);
        }

        // Decode body if decoder provided
        final decoded = decoder != null ? decoder(rawResponse.data) : null;
        return NetworkResponse<T>(
          statusCode: rawResponse.statusCode,
          data: decoded,
          headers: rawResponse.headers,
        );
      } catch (error) {
        if (retryPolicy != null &&
            retryPolicy.shouldRetry(
                attempt: attempt, error: error)) {
          final delay = retryPolicy.delay(attempt: attempt);
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
          attempt++;
          continue;
        }

        // Run error interceptors in reverse
        Object rethrowable = error;
        for (final interceptor in interceptors.reversed) {
          try {
            await interceptor.onError(rethrowable);
            break;
          } catch (e) {
            rethrowable = e;
          }
        }
        rethrow;
      }
    }
  }
}




/// Sentinel for timeout simulation in tests.
final class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

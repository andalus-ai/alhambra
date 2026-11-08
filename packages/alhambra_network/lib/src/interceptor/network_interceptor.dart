import '../request/network_request.dart';
import '../response/network_response.dart';

/// Composable interceptor hook for pre/post-processing network calls.
///
/// Chain order: interceptors applied in registration order on request;
/// reversed order on response/error.
abstract interface class NetworkInterceptor {
  /// Called before the request is dispatched. May mutate/replace the request.
  Future<NetworkRequest> onRequest(NetworkRequest request);

  /// Called after a response is received. May mutate/replace the response.
  Future<NetworkResponse<Object?>> onResponse(
      NetworkResponse<Object?> response);

  /// Called when an error is thrown. May rethrow, swallow, or convert.
  Future<Object?> onError(Object error);
}

/// No-op interceptor base — extend and override only what you need.
abstract base class BaseInterceptor implements NetworkInterceptor {
  const BaseInterceptor();

  @override
  Future<NetworkRequest> onRequest(NetworkRequest request) async => request;

  @override
  Future<NetworkResponse<Object?>> onResponse(
          NetworkResponse<Object?> response) async =>
      response;

  @override
  Future<Object?> onError(Object error) async => throw error;
}

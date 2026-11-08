import 'api_response.dart';

/// Transport-agnostic API client contract connecting API resource endpoints
/// to the underlying network transport (HTTP / RPC / Mock).
abstract interface class ApiClient {
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? query,
    T Function(Object? json)? decoder,
  });

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    T Function(Object? json)? decoder,
  });

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  });

  Future<ApiResponse<T>> delete<T>(
    String path, {
    T Function(Object? json)? decoder,
  });
}

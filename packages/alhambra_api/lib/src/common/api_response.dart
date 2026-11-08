import 'api_error.dart';
import 'api_metadata.dart';

/// Predictable envelope for all API responses across the platform.
final class ApiResponse<T> {
  final T? data;
  final ApiError? error;
  final ApiMetadata metadata;

  const ApiResponse.success({
    required T this.data,
    required this.metadata,
  }) : error = null;

  const ApiResponse.failure({
    required ApiError this.error,
    required this.metadata,
  }) : data = null;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  T get requireData {
    if (isFailure) {
      throw StateError('Cannot get data from failed ApiResponse: ${error!.message}');
    }
    return data as T;
  }

  @override
  String toString() => isSuccess ? 'ApiResponse.success($data)' : 'ApiResponse.failure($error)';
}

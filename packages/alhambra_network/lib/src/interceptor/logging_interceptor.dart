import '../request/network_request.dart';
import '../response/network_response.dart';
import 'network_interceptor.dart';

/// Pluggable log sink.
typedef NetworkLogger = void Function(String message);

/// Logs outgoing requests and incoming responses/errors to a configurable [logger].
final class LoggingInterceptor extends BaseInterceptor {
  final NetworkLogger logger;

  const LoggingInterceptor(this.logger);

  @override
  Future<NetworkRequest> onRequest(NetworkRequest request) async {
    logger(
        '→ ${request.method.name.toUpperCase()} ${request.path}'
        '${request.idempotencyKey != null ? ' [idem: ${request.idempotencyKey}]' : ''}');
    return request;
  }

  @override
  Future<NetworkResponse<Object?>> onResponse(
      NetworkResponse<Object?> response) async {
    logger('← ${response.statusCode}');
    return response;
  }

  @override
  Future<Object?> onError(Object error) async {
    logger('✗ Network error: $error');
    throw error;
  }
}

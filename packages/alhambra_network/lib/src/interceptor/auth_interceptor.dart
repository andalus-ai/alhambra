import '../authentication/auth_token_provider.dart';
import '../request/network_request.dart';
import '../response/network_response.dart';
import 'network_interceptor.dart';

/// Injects `Authorization: Bearer <token>` header from [AuthTokenProvider].
final class AuthInterceptor extends BaseInterceptor {
  final AuthTokenProvider _tokenProvider;

  const AuthInterceptor(this._tokenProvider);

  @override
  Future<NetworkRequest> onRequest(NetworkRequest request) async {
    final token = await _tokenProvider.getToken();
    if (token == null || token.isExpired) return request;

    final updatedHeaders = Map<String, String>.from(request.headers)
      ..['Authorization'] = token.authorizationHeaderValue;

    return request.copyWith(headers: updatedHeaders);
  }

  @override
  Future<NetworkResponse<Object?>> onResponse(
      NetworkResponse<Object?> response) async {
    if (response.isUnauthorized) {
      // Attempt token refresh — callers handle the refreshed re-request upstream
      await _tokenProvider.refreshToken();
    }
    return response;
  }
}

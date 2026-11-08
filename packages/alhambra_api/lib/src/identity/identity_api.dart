import '../common/api_response.dart';
import 'identity_dto.dart';

/// Resource endpoint contract for user identity, sessions, and organizations.
abstract interface class IdentityApi {
  Future<ApiResponse<UserDto>> getCurrentUser();

  Future<ApiResponse<UserDto>> getUser(String userId);

  Future<ApiResponse<OrganizationDto>> getOrganization(String organizationId);

  Future<ApiResponse<SessionDto>> createSession({
    required String email,
    required String password,
  });

  Future<ApiResponse<void>> revokeSession(String sessionId);
}

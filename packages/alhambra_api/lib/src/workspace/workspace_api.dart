import '../common/api_page.dart';
import '../common/api_response.dart';
import 'workspace_dto.dart';

/// Resource endpoint contract for workspaces, lifecycle progression, and publication.
abstract interface class WorkspaceApi {
  Future<ApiResponse<WorkspaceDto>> getWorkspace(String workspaceId);

  Future<ApiResponse<ApiPage<WorkspaceDto>>> listWorkspaces(
    WorkspaceListRequest request,
  );

  Future<ApiResponse<WorkspaceDto>> createWorkspace(
    CreateWorkspaceRequest request,
  );

  Future<ApiResponse<WorkspaceDto>> updateWorkspace(
    String workspaceId,
    UpdateWorkspaceRequest request,
  );

  Future<ApiResponse<void>> submitForReview(String workspaceId);

  Future<ApiResponse<void>> approve(
    String workspaceId, {
    String? comment,
  });

  Future<ApiResponse<void>> publish(String workspaceId);
}

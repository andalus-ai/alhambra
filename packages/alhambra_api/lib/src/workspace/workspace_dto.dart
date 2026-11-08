import '../common/api_request.dart';

/// DTO representation of a workspace resource.
final class WorkspaceDto {
  final String id;
  final String name;
  final String status;
  final int version;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;

  const WorkspaceDto({
    required this.id,
    required this.name,
    required this.status,
    required this.version,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  @override
  String toString() => 'WorkspaceDto($id: "$name" [$status, v$version])';
}

/// Request payload to create a new workspace.
final class CreateWorkspaceRequest extends ApiRequest {
  final String name;
  final String? description;

  const CreateWorkspaceRequest({
    required this.name,
    this.description,
    super.idempotencyKey,
  });
}

/// Request payload to update an existing workspace.
final class UpdateWorkspaceRequest extends ApiRequest {
  final String? name;
  final String? description;

  const UpdateWorkspaceRequest({
    this.name,
    this.description,
    super.idempotencyKey,
  });
}

/// Filter criteria for listing workspaces.
final class WorkspaceListRequest {
  final String? status;
  final int page;
  final int pageSize;

  const WorkspaceListRequest({
    this.status,
    this.page = 0,
    this.pageSize = 20,
  });
}

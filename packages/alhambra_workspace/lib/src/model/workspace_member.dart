import 'package:alhambra_core/alhambra_core.dart';

/// Workspace-level access role.
///
/// This is distinct and decoupled from organization-level roles in `alhambra_identity`.
enum WorkspaceRole {
  owner,
  editor,
  reviewer,
  viewer,
}

/// Represents a user's membership and assigned role within a specific workspace.
final class WorkspaceMember {
  final UserId userId;
  final WorkspaceRole role;

  const WorkspaceMember({
    required this.userId,
    required this.role,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceMember &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          role == other.role;

  @override
  int get hashCode => Object.hash(userId, role);

  @override
  String toString() => 'WorkspaceMember(user: $userId, role: $role)';
}

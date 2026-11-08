import 'package:alhambra_core/alhambra_core.dart';

import '../lifecycle/workspace_status.dart';
import 'workspace_member.dart';
import 'workspace_version.dart';

/// Generic, domain-agnostic Alhambra Workspace.
///
/// Decoupled from domain-specific intelligence or tooling concepts
/// (e.g. analysis, policies, knowledge bindings).
final class Workspace {
  final WorkspaceId id;
  final OrganizationId organizationId;
  final String name;
  final UserId ownerId;
  final WorkspaceStatus status;
  final WorkspaceVersion version;
  final List<WorkspaceMember> members;
  final Map<String, Object?> metadata;

  const Workspace({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.ownerId,
    required this.status,
    required this.version,
    this.members = const [],
    this.metadata = const {},
  });

  Workspace copyWith({
    WorkspaceId? id,
    OrganizationId? organizationId,
    String? name,
    UserId? ownerId,
    WorkspaceStatus? status,
    WorkspaceVersion? version,
    List<WorkspaceMember>? members,
    Map<String, Object?>? metadata,
  }) {
    return Workspace(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      version: version ?? this.version,
      members: members ?? this.members,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workspace &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          organizationId == other.organizationId &&
          status == other.status &&
          version == other.version;

  @override
  int get hashCode => Object.hash(id, organizationId, status, version);

  @override
  String toString() =>
      'Workspace(id: $id, name: $name, org: $organizationId, status: $status, v${version.number})';
}

import 'package:alhambra_core/alhambra_core.dart';

import 'permission.dart';

/// Unique identifier for a [Role].
final class RoleId extends AlhambraId {
  const RoleId(super.value);
}

/// A named collection of [Permission]s.
///
/// Roles are application-level configuration — Alhambra provides the
/// mechanism but does not define specific role names or assignments.
///
/// Example application roles:
/// - Analyst: workspace:create, workspace:read, analysis:execute
/// - Reviewer: workspace:read, workspace:approve
/// - Publisher: workspace:publish, workspace:read
final class Role {
  final RoleId id;
  final String name;
  final Set<Permission> permissions;

  const Role({
    required this.id,
    required this.name,
    this.permissions = const {},
  });

  /// Returns true if this role grants the given [permission].
  bool hasPermission(Permission permission) =>
      permissions.contains(permission);

  /// Returns true if this role grants permission with the given [key].
  bool hasPermissionKey(String key) =>
      permissions.any((p) => p.key == key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Role(id: $id, name: $name, permissions: ${permissions.length})';
}

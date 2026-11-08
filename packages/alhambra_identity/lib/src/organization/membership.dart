import 'package:alhambra_core/alhambra_core.dart';

/// Unique identifier for a [Membership].
final class MembershipId extends AlhambraId {
  const MembershipId(super.value);
}

/// Links a [User] to an [Organization], enabling multi-tenancy.
///
/// A user may hold memberships in multiple organizations simultaneously.
/// Roles and team assignments are attached to the membership rather than
/// the user, so the same user can have different roles in different contexts.
final class Membership {
  final MembershipId id;
  final UserId userId;
  final OrganizationId organizationId;

  /// Roles assigned to this membership within the organization.
  final Set<String> roleIds;

  /// Teams this user belongs to within the organization.
  final Set<String> teamIds;

  /// Whether this membership is currently active.
  ///
  /// Inactive memberships cannot be used to authorize access.
  final bool active;

  const Membership({
    required this.id,
    required this.userId,
    required this.organizationId,
    this.roleIds = const {},
    this.teamIds = const {},
    this.active = true,
  });

  Membership copyWith({
    MembershipId? id,
    UserId? userId,
    OrganizationId? organizationId,
    Set<String>? roleIds,
    Set<String>? teamIds,
    bool? active,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      organizationId: organizationId ?? this.organizationId,
      roleIds: roleIds ?? this.roleIds,
      teamIds: teamIds ?? this.teamIds,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Membership &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Membership(id: $id, user: $userId, org: $organizationId, roles: $roleIds, active: $active)';
}

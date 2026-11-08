import 'package:alhambra_core/alhambra_core.dart';
import '../organization/membership.dart';
import '../repository/membership_repository.dart';

/// Contract for managing user memberships in organizations.
abstract interface class MembershipService {
  Future<Membership> addMember({
    required UserId userId,
    required OrganizationId organizationId,
    Set<String> roleIds = const {},
    Set<String> teamIds = const {},
  });

  Future<Membership?> getMembership({
    required UserId userId,
    required OrganizationId organizationId,
  });

  Future<List<Membership>> getMembershipsForUser(UserId userId);

  Future<List<Membership>> getMembershipsForOrganization(OrganizationId organizationId);

  Future<void> assignRoles({
    required UserId userId,
    required OrganizationId organizationId,
    required Set<String> roleIds,
  });

  Future<void> revokeRoles({
    required UserId userId,
    required OrganizationId organizationId,
    required Set<String> roleIds,
  });

  Future<void> deactivateMember({
    required UserId userId,
    required OrganizationId organizationId,
  });
}

/// Standard implementation of [MembershipService].
final class DefaultMembershipService implements MembershipService {
  final MembershipRepository _membershipRepo;

  const DefaultMembershipService(this._membershipRepo);

  @override
  Future<Membership> addMember({
    required UserId userId,
    required OrganizationId organizationId,
    Set<String> roleIds = const {},
    Set<String> teamIds = const {},
  }) async {
    final existing = await _membershipRepo.findByUserAndOrg(userId, organizationId);
    if (existing != null) {
      final updated = existing.copyWith(
        active: true,
        roleIds: {...existing.roleIds, ...roleIds},
        teamIds: {...existing.teamIds, ...teamIds},
      );
      await _membershipRepo.save(updated);
      return updated;
    }

    final id = MembershipId('mbr-${DateTime.now().microsecondsSinceEpoch}');
    final membership = Membership(
      id: id,
      userId: userId,
      organizationId: organizationId,
      roleIds: roleIds,
      teamIds: teamIds,
      active: true,
    );
    await _membershipRepo.save(membership);
    return membership;
  }

  @override
  Future<Membership?> getMembership({
    required UserId userId,
    required OrganizationId organizationId,
  }) =>
      _membershipRepo.findByUserAndOrg(userId, organizationId);

  @override
  Future<List<Membership>> getMembershipsForUser(UserId userId) =>
      _membershipRepo.findByUser(userId);

  @override
  Future<List<Membership>> getMembershipsForOrganization(
          OrganizationId organizationId) =>
      _membershipRepo.findByOrg(organizationId);

  @override
  Future<void> assignRoles({
    required UserId userId,
    required OrganizationId organizationId,
    required Set<String> roleIds,
  }) async {
    final m = await _membershipRepo.findByUserAndOrg(userId, organizationId);
    if (m != null) {
      await _membershipRepo.save(m.copyWith(roleIds: {...m.roleIds, ...roleIds}));
    }
  }

  @override
  Future<void> revokeRoles({
    required UserId userId,
    required OrganizationId organizationId,
    required Set<String> roleIds,
  }) async {
    final m = await _membershipRepo.findByUserAndOrg(userId, organizationId);
    if (m != null) {
      final remaining = m.roleIds.difference(roleIds);
      await _membershipRepo.save(m.copyWith(roleIds: remaining));
    }
  }

  @override
  Future<void> deactivateMember({
    required UserId userId,
    required OrganizationId organizationId,
  }) async {
    final m = await _membershipRepo.findByUserAndOrg(userId, organizationId);
    if (m != null) {
      await _membershipRepo.save(m.copyWith(active: false));
    }
  }
}

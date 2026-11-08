import 'package:alhambra_core/alhambra_core.dart';

import '../organization/membership.dart';

/// Contract for membership persistence.
abstract interface class MembershipRepository {
  /// Returns the [Membership] for [userId] in [organizationId], or `null`.
  Future<Membership?> findByUserAndOrg(
    UserId userId,
    OrganizationId organizationId,
  );

  /// Returns all memberships for the given [userId].
  Future<List<Membership>> findByUser(UserId userId);

  /// Returns all memberships within the given [organizationId].
  Future<List<Membership>> findByOrg(OrganizationId organizationId);

  /// Persists (insert or update) the given [membership].
  Future<void> save(Membership membership);
}

/// In-memory implementation of [MembershipRepository] for testing.
final class InMemoryMembershipRepository implements MembershipRepository {
  final Map<String, Membership> _store = {};

  @override
  Future<Membership?> findByUserAndOrg(
    UserId userId,
    OrganizationId organizationId,
  ) async =>
      _store.values
          .where((m) => m.userId == userId && m.organizationId == organizationId)
          .firstOrNull;

  @override
  Future<List<Membership>> findByUser(UserId userId) async =>
      _store.values.where((m) => m.userId == userId).toList();

  @override
  Future<List<Membership>> findByOrg(OrganizationId organizationId) async =>
      _store.values.where((m) => m.organizationId == organizationId).toList();

  @override
  Future<void> save(Membership membership) async {
    _store[membership.id.value] = membership;
  }
}

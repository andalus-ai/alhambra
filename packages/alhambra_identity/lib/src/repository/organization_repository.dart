import 'package:alhambra_core/alhambra_core.dart';

import '../organization/organization.dart';

/// Contract for organization persistence.
abstract interface class OrganizationRepository {
  /// Returns the [Organization] with the given [id], or `null` if not found.
  Future<Organization?> findById(OrganizationId id);

  /// Returns all organizations the given [userId] is a member of.
  Future<List<Organization>> listForUser(UserId userId);

  /// Persists (insert or update) the given [organization].
  Future<void> save(Organization organization);
}

/// In-memory implementation of [OrganizationRepository] for testing.
final class InMemoryOrganizationRepository implements OrganizationRepository {
  final Map<String, Organization> _store = {};

  @override
  Future<Organization?> findById(OrganizationId id) async =>
      _store[id.value];

  @override
  Future<List<Organization>> listForUser(UserId userId) async =>
      _store.values.toList();

  @override
  Future<void> save(Organization organization) async {
    _store[organization.id.value] = organization;
  }
}

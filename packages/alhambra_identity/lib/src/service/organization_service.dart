import 'package:alhambra_core/alhambra_core.dart';
import '../organization/organization.dart';
import '../repository/organization_repository.dart';

/// Contract for managing organizational tenancy.
abstract interface class OrganizationService {
  Future<Organization> createOrganization({
    required String name,
    OrganizationTier tier = OrganizationTier.starter,
  });

  Future<Organization?> getOrganization(OrganizationId id);

  Future<void> updateOrganization(Organization organization);

  Future<void> deactivateOrganization(OrganizationId id);
}

/// Standard implementation of [OrganizationService].
final class DefaultOrganizationService implements OrganizationService {
  final OrganizationRepository _orgRepo;

  const DefaultOrganizationService(this._orgRepo);

  @override
  Future<Organization> createOrganization({
    required String name,
    OrganizationTier tier = OrganizationTier.starter,
  }) async {
    final id = OrganizationId('org-${DateTime.now().microsecondsSinceEpoch}');
    final org = Organization(
      id: id,
      name: name,
      tier: tier,
      active: true,
      createdAt: DateTime.now(),
    );
    await _orgRepo.save(org);
    return org;
  }

  @override
  Future<Organization?> getOrganization(OrganizationId id) =>
      _orgRepo.findById(id);

  @override
  Future<void> updateOrganization(Organization organization) =>
      _orgRepo.save(organization);

  @override
  Future<void> deactivateOrganization(OrganizationId id) async {
    final org = await _orgRepo.findById(id);
    if (org != null) {
      await _orgRepo.save(org.copyWith(active: false));
    }
  }
}

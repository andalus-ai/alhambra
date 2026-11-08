import 'package:alhambra_core/alhambra_core.dart';
import '../identity/principal.dart';

/// Context establishing an authenticated principal within an active organization tenancy.
final class OrganizationContext {
  final OrganizationId organizationId;
  final Principal principal;

  const OrganizationContext({
    required this.organizationId,
    required this.principal,
  });

  @override
  String toString() =>
      'OrganizationContext(org: $organizationId, principal: $principal)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationContext &&
          organizationId == other.organizationId &&
          principal == other.principal;

  @override
  int get hashCode => Object.hash(organizationId, principal);
}

import 'package:alhambra_core/alhambra_core.dart';

/// A protected resource in the Alhambra authorization model.
///
/// Deliberately generic — Alhambra does not know what types of resources
/// exist; the application defines them (e.g., 'workspace', 'analysis',
/// 'knowledge', 'artifact').
///
/// Named [AccessResource] (not `Resource`) to avoid collision with the
/// `Resource` interface exported from `alhambra_core`.
final class AccessResource {
  /// The type label of this resource, e.g. `'workspace'`, `'analysis'`.
  final String type;

  /// The unique identifier of the resource.
  final AlhambraId id;

  /// The owning organization, if applicable.
  final OrganizationId? organizationId;

  /// The owning user/principal ID, if applicable (e.g. for owner-cannot-approve rules).
  final String? ownerId;

  const AccessResource({
    required this.type,
    required this.id,
    this.organizationId,
    this.ownerId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessResource &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() =>
      'AccessResource(type: $type, id: $id, org: $organizationId, owner: $ownerId)';
}

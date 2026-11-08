import 'package:alhambra_core/alhambra_core.dart';

/// Unique identifier for a [Team].
final class TeamId extends AlhambraId {
  const TeamId(super.value);
}

/// A team within an [Organization].
///
/// Teams allow organizations to group members for more fine-grained
/// access control and collaboration. Alhambra does not prescribe team
/// names — those are defined by the application using the platform.
final class Team {
  final TeamId id;
  final OrganizationId organizationId;
  final String name;

  const Team({
    required this.id,
    required this.organizationId,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Team(id: $id, org: $organizationId, name: $name)';
}

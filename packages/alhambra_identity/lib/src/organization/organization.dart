import 'package:alhambra_core/alhambra_core.dart';
import 'package:meta/meta.dart';

/// Tier levels for an [Organization].
enum OrganizationTier { starter, growth, enterprise }

/// Primary multi-tenant boundary in the Alhambra platform.
@immutable
final class Organization {
  final OrganizationId id;
  final String name;
  final bool active;
  final OrganizationTier tier;
  final DateTime? createdAt;
  final Metadata metadata;

  const Organization({
    required this.id,
    required this.name,
    this.active = true,
    this.tier = OrganizationTier.starter,
    this.createdAt,
    this.metadata = const Metadata(),
  });

  /// Returns a copy of this organization with the given fields replaced.
  Organization copyWith({
    String? name,
    bool? active,
    OrganizationTier? tier,
    DateTime? createdAt,
    Metadata? metadata,
  }) =>
      Organization(
        id: id,
        name: name ?? this.name,
        active: active ?? this.active,
        tier: tier ?? this.tier,
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          runtimeType == other.runtimeType &&
          other.id == id &&
          other.name == name &&
          other.active == active &&
          other.tier == tier;

  @override
  int get hashCode => Object.hash(id, name, active, tier);

  @override
  String toString() =>
      'Organization($id, $name, tier: $tier, active: $active)';
}

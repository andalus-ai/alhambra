/// Defines the temporal, spatial, or resource scope of an intelligence request.
final class IntelligenceScope {
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> geographicEntities;
  final Set<String> targetEntities;
  final Map<String, Object?> filters;

  const IntelligenceScope({
    this.startDate,
    this.endDate,
    this.geographicEntities = const {},
    this.targetEntities = const {},
    this.filters = const {},
  });

  @override
  String toString() =>
      'IntelligenceScope(geo: $geographicEntities, targets: $targetEntities)';
}

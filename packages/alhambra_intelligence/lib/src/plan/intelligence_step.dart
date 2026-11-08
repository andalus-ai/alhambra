/// A discrete, executable step within an [IntelligencePlan].
final class IntelligenceStep {
  final String id;
  final String type;
  final List<String> dependsOn;
  final Map<String, Object?> parameters;

  const IntelligenceStep({
    required this.id,
    required this.type,
    this.dependsOn = const [],
    this.parameters = const {},
  });

  @override
  String toString() => 'IntelligenceStep($id: $type, deps: $dependsOn)';
}

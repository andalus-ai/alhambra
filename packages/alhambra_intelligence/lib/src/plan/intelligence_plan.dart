import 'intelligence_step.dart';

/// An executable sequence / DAG of steps planned to fulfill an [IntelligenceRequest].
final class IntelligencePlan {
  final String planId;
  final List<IntelligenceStep> steps;
  final Map<String, Object?> metadata;

  const IntelligencePlan({
    required this.planId,
    required this.steps,
    this.metadata = const {},
  });

  @override
  String toString() => 'IntelligencePlan($planId, steps: ${steps.length})';
}

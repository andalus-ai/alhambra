import 'intelligence_step.dart';

/// Mutable execution state passed across handlers during local/testing execution.
final class IntelligenceState {
  final Map<String, Object?> variables = {};
  final List<String> completedSteps = [];

  void set(String key, Object? value) => variables[key] = value;
  T? get<T>(String key) => variables[key] as T?;
}

/// Handler contract for executing specific step types.
abstract interface class IntelligenceStepHandler {
  Set<String> get supportedTypes;

  Future<void> execute(
    IntelligenceStep step,
    IntelligenceState state,
  );
}

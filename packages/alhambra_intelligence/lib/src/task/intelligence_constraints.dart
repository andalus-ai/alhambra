/// Constraints enforced upon intelligence execution (confidence, timeouts, privacy, budgets).
final class IntelligenceConstraints {
  final double? minimumConfidence;
  final Duration? timeout;
  final int? maxTokens;
  final bool requireHumanReview;
  final bool forbidSimulatedData;
  final Map<String, Object?> customConstraints;

  const IntelligenceConstraints({
    this.minimumConfidence,
    this.timeout,
    this.maxTokens,
    this.requireHumanReview = false,
    this.forbidSimulatedData = false,
    this.customConstraints = const {},
  });

  @override
  String toString() =>
      'IntelligenceConstraints(minConf: $minimumConfidence, review: $requireHumanReview)';
}

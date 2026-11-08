/// Typed objective specifying the goal of an intelligence task.
///
/// Domain applications configure specific objective types (e.g. 'economic.forecast',
/// 'education.assessment', 'mining.anomaly_detection') without changing the platform contract.
final class IntelligenceObjective {
  final String type;
  final Map<String, Object?> parameters;

  const IntelligenceObjective({
    required this.type,
    this.parameters = const {},
  });

  @override
  String toString() => 'IntelligenceObjective($type, params: $parameters)';
}

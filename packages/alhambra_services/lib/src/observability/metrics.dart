/// Generic metrics sink. Implementations delegate to Prometheus, StatsD,
/// Cloud Monitoring, or any compatible backend.
abstract interface class Metrics {
  /// Increments a counter by [value] (default 1).
  void increment(
    String name, {
    double value,
    Map<String, String> labels,
  });

  /// Sets a gauge to an absolute [value].
  void gauge(
    String name,
    double value, {
    Map<String, String> labels,
  });

  /// Records a timing measurement.
  void timing(
    String name,
    Duration duration, {
    Map<String, String> labels,
  });
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// Captured metric record for assertion in tests.
final class MetricRecord {
  final String name;
  final double value;
  final String type; // 'increment' | 'gauge' | 'timing'
  final Map<String, String> labels;

  const MetricRecord({
    required this.name,
    required this.value,
    required this.type,
    this.labels = const {},
  });

  @override
  String toString() => 'MetricRecord($type:$name=$value $labels)';
}

/// In-memory [Metrics] that captures records for test assertion.
final class InMemoryMetrics implements Metrics {
  final records = <MetricRecord>[];

  @override
  void increment(
    String name, {
    double value = 1,
    Map<String, String> labels = const {},
  }) =>
      records.add(MetricRecord(name: name, value: value, type: 'increment', labels: labels));

  @override
  void gauge(
    String name,
    double value, {
    Map<String, String> labels = const {},
  }) =>
      records.add(MetricRecord(name: name, value: value, type: 'gauge', labels: labels));

  @override
  void timing(
    String name,
    Duration duration, {
    Map<String, String> labels = const {},
  }) =>
      records.add(MetricRecord(
          name: name,
          value: duration.inMilliseconds.toDouble(),
          type: 'timing',
          labels: labels));
}

/// Health status of a platform component.
enum HealthStatus {
  /// Component is fully operational.
  healthy,

  /// Component is operational but with reduced capacity or elevated latency.
  degraded,

  /// Component is non-functional.
  unhealthy,

  /// Component health cannot currently be determined.
  unknown,
}

/// Result of a single named health probe.
final class HealthCheck {
  final String name;
  final HealthStatus status;
  final String? message;
  final Map<String, Object?> metadata;

  const HealthCheck({
    required this.name,
    required this.status,
    this.message,
    this.metadata = const {},
  });

  bool get isHealthy => status == HealthStatus.healthy;

  @override
  String toString() =>
      'HealthCheck($name: ${status.name}${message != null ? ' — $message' : ''})';
}

/// Aggregated health report.
final class HealthReport {
  final List<HealthCheck> checks;
  final DateTime checkedAt;

  const HealthReport({
    required this.checks,
    required this.checkedAt,
  });

  HealthStatus get overall {
    if (checks.any((c) => c.status == HealthStatus.unhealthy)) {
      return HealthStatus.unhealthy;
    }
    if (checks.any((c) => c.status == HealthStatus.degraded)) {
      return HealthStatus.degraded;
    }
    if (checks.any((c) => c.status == HealthStatus.unknown)) {
      return HealthStatus.unknown;
    }
    return HealthStatus.healthy;
  }
}

/// Platform health service — aggregates health probes from registered components.
abstract interface class HealthService {
  /// Runs all registered health probes and returns their results.
  Future<HealthReport> check();
}

// ---------------------------------------------------------------------------
// In-memory / composable implementation
// ---------------------------------------------------------------------------

typedef HealthProbe = Future<HealthCheck> Function();

/// [HealthService] that delegates to a list of registered [HealthProbe] functions.
final class ComposableHealthService implements HealthService {
  final List<HealthProbe> probes;

  const ComposableHealthService(this.probes);

  @override
  Future<HealthReport> check() async {
    final checks = await Future.wait(probes.map((p) => p()));
    return HealthReport(checks: checks, checkedAt: DateTime.now());
  }
}

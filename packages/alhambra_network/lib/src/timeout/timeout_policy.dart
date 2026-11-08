/// Per-operation timeout configuration.
final class TimeoutPolicy {
  /// Maximum time allowed to establish a connection.
  final Duration connect;

  /// Maximum time for the full request/response cycle.
  final Duration request;

  /// Maximum idle time when receiving response data.
  final Duration receive;

  const TimeoutPolicy({
    this.connect = const Duration(seconds: 10),
    this.request = const Duration(seconds: 30),
    this.receive = const Duration(seconds: 30),
  });

  /// Longer policy suitable for file uploads.
  static const upload = TimeoutPolicy(
    connect: Duration(seconds: 10),
    request: Duration(minutes: 5),
    receive: Duration(minutes: 5),
  );

  /// Long-lived streaming connections (SSE / WebSocket).
  static const streaming = TimeoutPolicy(
    connect: Duration(seconds: 10),
    request: Duration(hours: 24),
    receive: Duration(hours: 24),
  );
}

import 'dart:math' as math;

/// An active trace span tracking a unit of work.
abstract interface class Span {
  /// Unique span identifier (e.g. W3C trace-context span ID).
  String get id;

  /// Sets a typed attribute on the span.
  void setAttribute(String key, Object? value);

  /// Records an error that occurred within this span.
  void recordError(Object error, StackTrace? stackTrace);

  /// Ends the span and flushes it to the backend.
  Future<void> end();
}

/// Distributed tracing contract.
///
/// Connect to OpenTelemetry, Jaeger, Zipkin, or a custom backend via
/// concrete implementations. The platform itself only calls this interface.
abstract interface class Tracer {
  /// Starts a new span named [name].
  Span startSpan(
    String name, {
    Map<String, Object?> attributes,
  });
}

// ---------------------------------------------------------------------------
// No-op / in-memory implementations for tests
// ---------------------------------------------------------------------------

/// No-op [Span] — captures attributes for assertion.
final class NoOpSpan implements Span {
  @override
  final String id;

  final attributes = <String, Object?>{};
  final errors = <Object>[];
  bool ended = false;

  NoOpSpan() : id = _randomId();

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void recordError(Object error, StackTrace? stackTrace) =>
      errors.add(error);

  @override
  Future<void> end() async => ended = true;

  static String _randomId() =>
      math.Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
}

/// No-op [Tracer] — creates [NoOpSpan]s for tests.
final class NoOpTracer implements Tracer {
  final spans = <NoOpSpan>[];

  @override
  NoOpSpan startSpan(String name, {Map<String, Object?> attributes = const {}}) {
    final span = NoOpSpan();
    for (final e in attributes.entries) {
      span.setAttribute(e.key, e.value);
    }
    spans.add(span);
    return span;
  }
}

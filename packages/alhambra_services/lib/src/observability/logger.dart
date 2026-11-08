/// Structured application logger. Implementations may delegate to
/// `package:logging`, console output, or a remote telemetry backend.
abstract interface class Logger {
  void debug(String message, {Map<String, Object?> context});
  void info(String message, {Map<String, Object?> context});
  void warning(String message, {Map<String, Object?> context});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context,
  });
}

// ---------------------------------------------------------------------------
// Console / test implementations
// ---------------------------------------------------------------------------

/// Log level for filtering.
enum LogLevel { debug, info, warning, error }

/// Simple console [Logger]. Filters below [minLevel].
final class ConsoleLogger implements Logger {
  final String name;
  final LogLevel minLevel;

  const ConsoleLogger(this.name, {this.minLevel = LogLevel.debug});

  void _log(LogLevel level, String message, Map<String, Object?> ctx) {
    if (level.index < minLevel.index) return;
    final prefix = '[${level.name.toUpperCase()}] $name';
    // ignore: avoid_print
    print('$prefix: $message${ctx.isNotEmpty ? ' $ctx' : ''}');
  }

  @override
  void debug(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.debug, message, context);

  @override
  void info(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.info, message, context);

  @override
  void warning(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.warning, message, context);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _log(LogLevel.error, message, {
      ...context,
      if (error != null) 'error': error.toString(),
    });
  }
}

/// Captures log records for test assertions.
final class CapturingLogger implements Logger {
  final records = <({LogLevel level, String message, Map<String, Object?> ctx})>[];

  @override
  void debug(String message, {Map<String, Object?> context = const {}}) =>
      records.add((level: LogLevel.debug, message: message, ctx: context));

  @override
  void info(String message, {Map<String, Object?> context = const {}}) =>
      records.add((level: LogLevel.info, message: message, ctx: context));

  @override
  void warning(String message, {Map<String, Object?> context = const {}}) =>
      records.add((level: LogLevel.warning, message: message, ctx: context));

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) =>
      records.add((level: LogLevel.error, message: message, ctx: context));

  bool get hasErrors => records.any((r) => r.level == LogLevel.error);
}

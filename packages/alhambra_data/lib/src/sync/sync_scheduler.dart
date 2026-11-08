import 'dart:math';

/// Exponential backoff configuration for sync retry scheduling.
final class BackoffConfig {
  final Duration initial;
  final Duration maximum;
  final double multiplier;

  const BackoffConfig({
    this.initial = const Duration(seconds: 5),
    this.maximum = const Duration(minutes: 2),
    this.multiplier = 2.0,
  });

  /// Computes the delay for attempt number [attempt] (1-based).
  Duration delayFor(int attempt) {
    final ms = initial.inMilliseconds * pow(multiplier, attempt - 1);
    return Duration(
      milliseconds: min(ms.toInt(), maximum.inMilliseconds),
    );
  }
}

/// Sync scheduler — wraps backoff logic and coordinates retry timing.
///
/// The sync engine uses this to decide when to re-attempt failed operations.
final class SyncScheduler {
  final BackoffConfig config;

  const SyncScheduler({this.config = const BackoffConfig()});

  /// Returns the duration to wait before the next retry for [attemptCount].
  ///
  /// [attemptCount] is the number of previous failures (0 = first failure).
  Duration nextDelay(int attemptCount) => config.delayFor(attemptCount + 1);

  /// Returns `true` if enough time has elapsed since [lastAttemptAt] to retry.
  bool shouldRetry({
    required int attemptCount,
    required DateTime lastAttemptAt,
    DateTime? now,
  }) {
    final elapsed = (now ?? DateTime.now()).difference(lastAttemptAt);
    return elapsed >= nextDelay(attemptCount);
  }
}

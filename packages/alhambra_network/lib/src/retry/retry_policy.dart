/// Governs whether and how a failed network call should be retried.
abstract interface class RetryPolicy {
  /// Returns true if the [attempt] (0-indexed) should trigger another try.
  bool shouldRetry({
    required int attempt,
    required Object error,
    int? statusCode,
  });

  /// Delay before the next attempt; implementations may use exponential backoff.
  Duration delay({required int attempt});
}

/// Exponential backoff retry with a configurable cap.
final class ExponentialBackoffRetryPolicy implements RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final Set<int> retryableStatusCodes;

  const ExponentialBackoffRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  @override
  bool shouldRetry({
    required int attempt,
    required Object error,
    int? statusCode,
  }) {
    if (attempt >= maxAttempts) return false;
    if (statusCode != null) return retryableStatusCodes.contains(statusCode);
    // Network-level errors (no status code) are retryable
    return true;
  }

  @override
  Duration delay({required int attempt}) {
    final ms = initialDelay.inMilliseconds * (1 << attempt);
    return Duration(milliseconds: ms.clamp(0, maxDelay.inMilliseconds));
  }
}

/// Never-retry policy — for critical single-shot operations (e.g. auth mutations).
final class NoRetryPolicy implements RetryPolicy {
  const NoRetryPolicy();

  @override
  bool shouldRetry({
    required int attempt,
    required Object error,
    int? statusCode,
  }) =>
      false;

  @override
  Duration delay({required int attempt}) => Duration.zero;
}

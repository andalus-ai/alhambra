/// Classified presentation-level error model.
///
/// Maps raw errors (HTTP status codes, exceptions) to user-facing
/// categories with appropriate messaging. Backend details are never
/// surfaced to the user.
enum UiErrorClass {
  /// Network unreachable or timed out.
  network,

  /// 401 — session expired or not authenticated.
  unauthenticated,

  /// 403 — user lacks permission.
  authorization,

  /// 404 — resource not found.
  notFound,

  /// 409 — optimistic concurrency conflict.
  conflict,

  /// 400/422 — client submitted invalid data.
  validation,

  /// 5xx — server-side failure.
  server,

  /// Unknown / unexpected error.
  unknown,
}

/// Extension providing human-readable messaging for [UiErrorClass].
extension UiErrorClassMessage on UiErrorClass {
  /// Short headline shown in error states.
  String get headline => switch (this) {
        UiErrorClass.network => 'Connection problem',
        UiErrorClass.unauthenticated => 'Session expired',
        UiErrorClass.authorization =>
          "You don't have permission to do this",
        UiErrorClass.notFound => 'Not found',
        UiErrorClass.conflict => 'Conflict — this item was updated elsewhere',
        UiErrorClass.validation => 'Please check the information provided',
        UiErrorClass.server => 'Something went wrong on our end',
        UiErrorClass.unknown => 'An unexpected error occurred',
      };

  /// Supplementary guidance shown below the headline.
  String get guidance => switch (this) {
        UiErrorClass.network =>
          'Check your connection and try again',
        UiErrorClass.unauthenticated => 'Sign in again to continue',
        UiErrorClass.authorization =>
          'Contact your administrator if you need access',
        UiErrorClass.notFound =>
          'The item may have been removed or moved',
        UiErrorClass.conflict =>
          'Refresh to see the latest version',
        UiErrorClass.validation =>
          'Correct the highlighted fields and try again',
        UiErrorClass.server => 'Try again in a moment',
        UiErrorClass.unknown => 'Try again or contact support',
      };

  /// Whether a retry action should be offered to the user.
  bool get isRetryable => switch (this) {
        UiErrorClass.network => true,
        UiErrorClass.server => true,
        UiErrorClass.conflict => true,
        _ => false,
      };
}

/// Classifies an HTTP status code or common exception into a [UiErrorClass].
UiErrorClass classifyHttpError(int statusCode) => switch (statusCode) {
      401 => UiErrorClass.unauthenticated,
      403 => UiErrorClass.authorization,
      404 => UiErrorClass.notFound,
      408 => UiErrorClass.network,
      409 => UiErrorClass.conflict,
      422 => UiErrorClass.validation,
      >= 400 && < 500 => UiErrorClass.validation,
      >= 500 => UiErrorClass.server,
      _ => UiErrorClass.unknown,
    };

/// Classified error value combining class + optional detail for logging.
final class UiError {
  final UiErrorClass errorClass;

  /// Internal detail — for logging only, never shown to the user.
  final Object? internalDetail;

  const UiError(this.errorClass, {this.internalDetail});

  factory UiError.fromHttpStatus(int statusCode, {Object? detail}) =>
      UiError(classifyHttpError(statusCode), internalDetail: detail);

  factory UiError.network({Object? detail}) =>
      UiError(UiErrorClass.network, internalDetail: detail);

  factory UiError.unknown({Object? detail}) =>
      UiError(UiErrorClass.unknown, internalDetail: detail);

  String get headline => errorClass.headline;
  String get guidance => errorClass.guidance;
  bool get isRetryable => errorClass.isRetryable;

  @override
  String toString() => 'UiError(${errorClass.name})';
}

/// Standardized API error payload.
final class ApiError {
  final String code;
  final String message;
  final Map<String, Object?> details;

  const ApiError({
    required this.code,
    required this.message,
    this.details = const {},
  });

  @override
  String toString() => 'ApiError($code: $message)';
}

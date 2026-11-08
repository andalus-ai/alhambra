import 'package:meta/meta.dart';

/// Machine-readable standard error codes across the Alhambra platform.
abstract final class ErrorCode {
  // General / Domain
  static const String unknown = 'system.unknown';
  static const String validationFailed = 'validation.failed';
  static const String notFound = 'resource.not_found';
  static const String alreadyExists = 'resource.already_exists';

  // Workspace
  static const String workspaceNotFound = 'workspace.not_found';
  static const String workspaceInvalidState = 'workspace.invalid_state';

  // Authorization / Security
  static const String unauthenticated = 'auth.unauthenticated';
  static const String unauthorized = 'auth.unauthorized';
  static const String permissionDenied = 'auth.permission_denied';
  static const String sessionExpired = 'auth.session_expired';

  // Storage / Persistence
  static const String storageUnavailable = 'storage.unavailable';
  static const String storageReadFailed = 'storage.read_failed';
  static const String storageWriteFailed = 'storage.write_failed';

  // Sync / Concurrency
  static const String syncConflict = 'sync.conflict';
  static const String versionMismatch = 'sync.version_mismatch';

  // Network / Transport
  static const String networkTimeout = 'network.timeout';
  static const String serviceUnavailable = 'network.service_unavailable';
}

/// Structured, machine-readable and human-friendly error representation.
@immutable
final class AlhambraError {
  /// Machine-readable error code (e.g. 'workspace.not_found', 'validation.failed').
  final String code;

  /// Human-readable diagnostic description of what failed.
  final String message;

  /// Optional underlying exception or failure cause.
  final Object? cause;

  /// Optional stack trace associated with the failure.
  final StackTrace? stackTrace;

  /// Diagnostic metadata or context key-value pairs.
  final Map<String, Object?> metadata;

  const AlhambraError({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
    this.metadata = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlhambraError &&
          runtimeType == other.runtimeType &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'AlhambraError($code: $message)';
}

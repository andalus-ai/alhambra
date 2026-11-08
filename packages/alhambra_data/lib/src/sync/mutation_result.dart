import 'package:meta/meta.dart';

/// Synchronization-aware result returned by repository mutations.
///
/// The UI can distinguish `Saved` from `Saved locally — awaiting server`.
enum MutationStatus {
  /// The mutation was accepted and confirmed by the server.
  synchronized,

  /// The mutation was accepted locally and is queued for server sync.
  pending,

  /// The server rejected the mutation due to a version conflict.
  conflict,

  /// The server permanently rejected the mutation (auth, validation, etc.).
  rejected,
}

/// Wraps a mutation outcome with its sync state and an optional operation ID
/// that can be tracked in the offline queue.
@immutable
final class MutationResult<T> {
  final T value;
  final MutationStatus status;

  /// The ID of the queued [SyncOperation], if the mutation is pending.
  final String? operationId;

  const MutationResult({
    required this.value,
    required this.status,
    this.operationId,
  });

  /// Convenience: fully synchronized result with no pending operation.
  const MutationResult.synchronized(T value)
      : this(value: value, status: MutationStatus.synchronized);

  /// Convenience: pending result from an offline or deferred mutation.
  const MutationResult.pending(T value, {String? operationId})
      : this(
          value: value,
          status: MutationStatus.pending,
          operationId: operationId,
        );

  /// Convenience: conflict result.
  const MutationResult.conflict(T value)
      : this(value: value, status: MutationStatus.conflict);

  /// Convenience: rejected result.
  const MutationResult.rejected(T value)
      : this(value: value, status: MutationStatus.rejected);

  bool get isSynchronized => status == MutationStatus.synchronized;
  bool get isPending => status == MutationStatus.pending;
  bool get isConflict => status == MutationStatus.conflict;
  bool get isRejected => status == MutationStatus.rejected;

  @override
  String toString() =>
      'MutationResult(status: $status, operationId: $operationId)';
}

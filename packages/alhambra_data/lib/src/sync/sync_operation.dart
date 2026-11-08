/// P12 hardened SyncOperation with idempotency, tenant context,
/// version concurrency, retry tracking, and status.
final class SyncOperation {
  /// Unique operation ID (also serves as the deduplication key).
  final String id;

  /// Stable idempotency key — must survive retries across network failures.
  /// The server can use this to deduplicate replayed requests.
  final String idempotencyKey;

  /// Domain resource type (e.g. `'workspace'`, `'artifact'`).
  final String resourceType;

  /// The specific resource being mutated.
  final String resourceId;

  /// The operation being performed (e.g. `'create'`, `'update'`, `'delete'`).
  final String operation;

  /// Organization that owns this mutation — immutable after creation.
  ///
  /// Operations whose [organizationId] differs from the current active
  /// organization context must **not** be dispatched (tenant safety).
  final String? organizationId;

  /// The version the client based its mutation on (optimistic concurrency).
  ///
  /// The server rejects mutations where [baseVersion] ≠ current server version.
  final int? baseVersion;

  final DateTime createdAt;

  /// How many times the sync engine has attempted this operation.
  final int attemptCount;

  /// Timestamp of the most recent attempt, or `null` if never attempted.
  final DateTime? lastAttemptAt;

  /// Current status of the operation in the sync state machine.
  final SyncOperationStatus status;

  /// Domain-specific mutation payload.
  final Map<String, Object?> payload;

  const SyncOperation({
    required this.id,
    required this.idempotencyKey,
    required this.resourceType,
    required this.resourceId,
    required this.operation,
    required this.createdAt,
    this.organizationId,
    this.baseVersion,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.status = SyncOperationStatus.pending,
    this.payload = const {},
  });

  /// Returns a copy of this operation with updated fields.
  SyncOperation copyWith({
    int? attemptCount,
    DateTime? lastAttemptAt,
    SyncOperationStatus? status,
  }) =>
      SyncOperation(
        id: id,
        idempotencyKey: idempotencyKey,
        resourceType: resourceType,
        resourceId: resourceId,
        operation: operation,
        organizationId: organizationId,
        baseVersion: baseVersion,
        createdAt: createdAt,
        attemptCount: attemptCount ?? this.attemptCount,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        status: status ?? this.status,
        payload: payload,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SyncOperation(id: $id, resource: $resourceType/$resourceId, '
      'op: $operation, status: $status, attempts: $attemptCount)';
}

/// Per-operation sync state machine.
///
/// ```text
/// PENDING
///    ↓
/// SYNCING
///    ├── 2xx ───────────→ SUCCEEDED
///    ├── 409 ───────────→ CONFLICT
///    ├── 401 ───────────→ UNAUTHORIZED
///    ├── 403 ───────────→ FAILED
///    ├── 5xx ───────────→ RETRYING
///    └── network ───────→ RETRYING
/// ```
enum SyncOperationStatus {
  /// Queued, not yet attempted.
  pending,

  /// Currently being dispatched.
  syncing,

  /// Server accepted the mutation (2xx).
  succeeded,

  /// Transient failure — will be retried with backoff.
  retrying,

  /// Version mismatch or resource changed remotely (HTTP 409).
  conflict,

  /// Authentication/session failure — requires re-authentication.
  unauthorized,

  /// Permanent failure — forbidden, bad request, business-rule violation.
  failed,
}

/// Classifies an error response for routing in the sync state machine.
enum SyncErrorClass {
  /// Transient failures — retry with backoff (network, timeouts, 5xx).
  retryable,

  /// Version mismatch / remote resource changed (409).
  conflict,

  /// Session expired or credentials invalid (401).
  authenticationExpired,

  /// Permanent: forbidden, not found, validation error (403, 400, 404).
  nonRetryable,
}

/// Maps HTTP status codes / error conditions to [SyncErrorClass].
SyncErrorClass classifySyncError({int? httpStatus, bool isNetworkError = false}) {
  if (isNetworkError) return SyncErrorClass.retryable;
  return switch (httpStatus) {
    401 => SyncErrorClass.authenticationExpired,
    409 => SyncErrorClass.conflict,
    400 || 403 || 404 || 422 => SyncErrorClass.nonRetryable,
    final s when s != null && s >= 500 => SyncErrorClass.retryable,
    _ => SyncErrorClass.retryable,
  };
}

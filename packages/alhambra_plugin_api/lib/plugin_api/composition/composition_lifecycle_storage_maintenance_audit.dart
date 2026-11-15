import 'package:alhambra_plugin_api/plugin_api/composition/composition_lifecycle_storage_maintenance_coordinator.dart';

/// Stable keyset cursor for maintenance audit history.
///
/// Ordering is the composite tuple `(startedAt, operationId, status.name)`.
/// All bounds are exclusive and results are oldest-first.
final class CompositionLifecycleStorageMaintenanceAuditCursor {
  final DateTime startedAt;
  final String operationId;
  final CompositionLifecycleStorageMaintenanceOperationStatus status;

  const CompositionLifecycleStorageMaintenanceAuditCursor({
    required this.startedAt,
    required this.operationId,
    required this.status,
  }) : assert(operationId != '');
}

/// Query bounds for a maintenance audit store.
///
/// [from] and [to] are inclusive. [after] is an exclusive composite cursor.
/// Implementations must apply all supplied filters before enforcing [limit].
final class CompositionLifecycleStorageMaintenanceAuditQuery {
  final String? operationId;
  final CompositionLifecycleStorageMaintenanceOperationStatus? status;
  final DateTime? from;
  final DateTime? to;
  final CompositionLifecycleStorageMaintenanceAuditCursor? after;
  final int limit;

  CompositionLifecycleStorageMaintenanceAuditQuery({
    this.operationId,
    this.status,
    this.from,
    this.to,
    this.after,
    this.limit = 100,
  }) {
    if (operationId != null && operationId!.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    if (from != null && to != null && from!.isAfter(to!)) {
      throw ArgumentError('The from bound must not be after the to bound.');
    }
  }
}

/// Queryable durable audit capability for maintenance operations.
///
/// This optional capability extends the append-only sink used by the
/// coordinator. Implementations should make append idempotent for the same
/// `(operationId, status)` and identical payload. Reusing that key with a
/// different payload, or appending a second incompatible terminal record for
/// one operation, must fail with an identity-conflict error.
///
/// Query results must be ordered oldest-first by
/// `(startedAt, operationId, status.name)`, apply every query bound, and
/// contain at most [query.limit] records. A successful append must cross the
/// adapter's documented durability boundary.
abstract interface class CompositionLifecycleStorageMaintenanceAuditStore
    implements CompositionLifecycleStorageMaintenanceAuditLog {
  Future<List<CompositionLifecycleStorageMaintenanceOperationRecord>> query(
    CompositionLifecycleStorageMaintenanceAuditQuery query,
  );
}

/// Reusing an audit identity with a different maintenance record is a conflict.
final class CompositionLifecycleStorageMaintenanceAuditIdentityConflictException
    implements Exception {
  final String operationId;
  final CompositionLifecycleStorageMaintenanceOperationStatus status;

  const CompositionLifecycleStorageMaintenanceAuditIdentityConflictException({
    required this.operationId,
    required this.status,
  });

  @override
  String toString() =>
      'Maintenance audit identity "$operationId/${status.name}" has a conflicting payload.';
}

/// Recovery interpretation of the durable audit records for one operation.
enum CompositionLifecycleStorageMaintenanceRecoveryState {
  /// No matching audit records exist.
  notFound,

  /// A start record exists, but no terminal record proves the outcome.
  outcomeUnknown,

  /// A terminal record exists without its corresponding start record.
  incompleteHistory,

  /// Conflicting start or terminal records prevent a safe interpretation.
  conflictingHistory,

  /// A start and exactly one terminal record establish a known outcome.
  completed,
}

/// Conservative, adapter-neutral interpretation of one operation's history.
///
/// This helper never retries or resumes work. An operation with a start record
/// and no terminal record is classified as [outcomeUnknown], because the
/// executor may have completed destructive work before the process stopped.
/// Hosts must not automatically replay such work unless the executor provides
/// its own idempotency/reconciliation guarantee.
final class CompositionLifecycleStorageMaintenanceRecovery {
  final String operationId;
  final CompositionLifecycleStorageMaintenanceRecoveryState state;
  final CompositionLifecycleStorageMaintenanceOperationRecord? started;
  final CompositionLifecycleStorageMaintenanceOperationRecord? terminal;

  const CompositionLifecycleStorageMaintenanceRecovery._({
    required this.operationId,
    required this.state,
    required this.started,
    required this.terminal,
  });

  factory CompositionLifecycleStorageMaintenanceRecovery.classify({
    required String operationId,
    required Iterable<CompositionLifecycleStorageMaintenanceOperationRecord>
        records,
  }) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }

    final matching = records.where((record) => record.operationId == operationId);
    final starts = matching
        .where((record) =>
            record.status == CompositionLifecycleStorageMaintenanceOperationStatus.started)
        .toList(growable: false);
    final terminals = matching
        .where((record) =>
            record.status != CompositionLifecycleStorageMaintenanceOperationStatus.started)
        .toList(growable: false);

    if (starts.isEmpty && terminals.isEmpty) {
      return CompositionLifecycleStorageMaintenanceRecovery._(
        operationId: operationId,
        state: CompositionLifecycleStorageMaintenanceRecoveryState.notFound,
        started: null,
        terminal: null,
      );
    }

    if (starts.length > 1 || terminals.length > 1) {
      return CompositionLifecycleStorageMaintenanceRecovery._(
        operationId: operationId,
        state: CompositionLifecycleStorageMaintenanceRecoveryState.conflictingHistory,
        started: starts.length == 1 ? starts.single : null,
        terminal: terminals.length == 1 ? terminals.single : null,
      );
    }

    if (starts.isEmpty) {
      return CompositionLifecycleStorageMaintenanceRecovery._(
        operationId: operationId,
        state: CompositionLifecycleStorageMaintenanceRecoveryState.incompleteHistory,
        started: null,
        terminal: terminals.single,
      );
    }

    if (terminals.isEmpty) {
      return CompositionLifecycleStorageMaintenanceRecovery._(
        operationId: operationId,
        state: CompositionLifecycleStorageMaintenanceRecoveryState.outcomeUnknown,
        started: starts.single,
        terminal: null,
      );
    }

    final start = starts.single;
    final end = terminals.single;
    if (end.startedAt != start.startedAt ||
        end.requestedAt != start.requestedAt ||
        !_sameRequest(end.request, start.request) ||
        end.completedAt == null ||
        end.completedAt!.isBefore(start.startedAt)) {
      return CompositionLifecycleStorageMaintenanceRecovery._(
        operationId: operationId,
        state: CompositionLifecycleStorageMaintenanceRecoveryState.conflictingHistory,
        started: start,
        terminal: end,
      );
    }

    return CompositionLifecycleStorageMaintenanceRecovery._(
      operationId: operationId,
      state: CompositionLifecycleStorageMaintenanceRecoveryState.completed,
      started: start,
      terminal: end,
    );
  }

  /// Whether a host must obtain an explicit reconciliation decision.
  bool get requiresReconciliation =>
      state == CompositionLifecycleStorageMaintenanceRecoveryState.outcomeUnknown ||
      state == CompositionLifecycleStorageMaintenanceRecoveryState.incompleteHistory ||
      state == CompositionLifecycleStorageMaintenanceRecoveryState.conflictingHistory;

  /// A terminal status is available only when history is internally complete.
  CompositionLifecycleStorageMaintenanceOperationStatus? get terminalStatus =>
      state == CompositionLifecycleStorageMaintenanceRecoveryState.completed
          ? terminal!.status
          : null;

  /// Automatic replay is never authorized by audit history alone.
  ///
  /// Even a known failed outcome may have performed partial external work;
  /// the executor/adapter must supply a stronger retry-safety guarantee.
  bool get automaticRetryAllowed => false;
}

bool _sameRequest(
  CompositionLifecycleStorageMaintenanceRequest left,
  CompositionLifecycleStorageMaintenanceRequest right,
) =>
    left.retainFrom == right.retainFrom &&
    left.maxEvents == right.maxEvents &&
    left.checkpoint == right.checkpoint;

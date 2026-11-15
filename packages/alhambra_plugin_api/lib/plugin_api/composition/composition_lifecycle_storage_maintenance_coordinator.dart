import 'dart:async';

import 'composition_lifecycle_storage_maintenance.dart';

/// Terminal or in-progress state of a coordinated maintenance operation.
enum CompositionLifecycleStorageMaintenanceOperationStatus {
  started,
  succeeded,
  partial,
  failed,
  cancelled,
}

/// Immutable audit record emitted by a maintenance coordinator.
///
/// Hosts choose the persistence and retention strategy for these records.
/// The coordinator never claims that an in-memory callback is durable.
final class CompositionLifecycleStorageMaintenanceOperationRecord {
  final String operationId;
  final CompositionLifecycleStorageMaintenanceOperationStatus status;
  final DateTime requestedAt;
  final DateTime startedAt;
  final DateTime? completedAt;
  final CompositionLifecycleStorageMaintenanceRequest request;
  final CompositionLifecycleStorageMaintenanceResult? result;
  final String? error;

  CompositionLifecycleStorageMaintenanceOperationRecord({
    required this.operationId,
    required this.status,
    required this.requestedAt,
    required this.startedAt,
    this.completedAt,
    required this.request,
    this.result,
    this.error,
  }) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }
    if (completedAt != null && completedAt!.isBefore(startedAt)) {
      throw ArgumentError('completedAt must not be before startedAt.');
    }
    if (status == CompositionLifecycleStorageMaintenanceOperationStatus.started &&
        completedAt != null) {
      throw ArgumentError('A started record cannot have completedAt.');
    }
    if (status != CompositionLifecycleStorageMaintenanceOperationStatus.started &&
        completedAt == null) {
      throw ArgumentError('A terminal record must have completedAt.');
    }
  }
}

/// Host-owned audit sink for maintenance operation records.
///
/// Implementations should persist records durably when audit guarantees are
/// required. The coordinator writes the started record before invoking the
/// executor (fail-closed), then writes one terminal record after execution.
abstract interface class CompositionLifecycleStorageMaintenanceAuditLog {
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  );
}

/// Cooperative cancellation signal supplied to the host's executor.
///
/// Cancellation before the executor starts prevents execution. Once execution
/// has started, the executor must inspect this signal at safe boundaries. The
/// coordinator never abandons an in-flight Future or assumes that destructive
/// work was rolled back.
final class CompositionLifecycleStorageMaintenanceCancellation {
  bool _requested = false;

  bool get isCancellationRequested => _requested;

  void requestCancellation() {
    _requested = true;
  }
}

/// Executes one explicit maintenance request.
///
/// Executors should check [cancellation] before destructive phases and return
/// a partial result with a warning if cancellation arrives after work has
/// started and cannot safely be rolled back.
typedef CompositionLifecycleStorageMaintenanceExecutor = Future<
    CompositionLifecycleStorageMaintenanceResult> Function(
  CompositionLifecycleStorageMaintenanceRequest request,
  CompositionLifecycleStorageMaintenanceCancellation cancellation,
);

/// Result returned when a coordinated maintenance operation finishes.
final class CompositionLifecycleStorageMaintenanceOperationOutcome {
  final String operationId;
  final CompositionLifecycleStorageMaintenanceOperationStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final CompositionLifecycleStorageMaintenanceResult? result;
  final String? error;
  final String? auditError;
  final bool cancellationRequested;

  const CompositionLifecycleStorageMaintenanceOperationOutcome({
    required this.operationId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    this.result,
    this.error,
    this.auditError,
    required this.cancellationRequested,
  });

  bool get succeeded =>
      status == CompositionLifecycleStorageMaintenanceOperationStatus.succeeded;
}

/// Handle for a started maintenance operation.
final class CompositionLifecycleStorageMaintenanceHandle {
  final CompositionLifecycleStorageMaintenanceCancellation _cancellation;
  final Future<CompositionLifecycleStorageMaintenanceOperationOutcome> outcome;

  const CompositionLifecycleStorageMaintenanceHandle._({
    required CompositionLifecycleStorageMaintenanceCancellation cancellation,
    required this.outcome,
  }) : _cancellation = cancellation;

  /// Requests cooperative cancellation.
  ///
  /// If the executor has not started, it will not be invoked. Otherwise the
  /// signal is visible to the executor; this method does not interrupt I/O.
  void cancel() => _cancellation.requestCancellation();
}

/// Single-flight coordinator for one host-defined lifecycle store scope.
///
/// One coordinator instance prevents overlapping operations submitted through
/// that instance only. It does not provide cross-instance or cross-process
/// locking. Hosts must share an instance or provide stronger external
/// coordination when multiple writers can target the same store.
final class CompositionLifecycleStorageMaintenanceCoordinator {
  final CompositionLifecycleStorageMaintenanceAuditLog? auditLog;
  final DateTime Function() _clock;
  bool _active = false;

  CompositionLifecycleStorageMaintenanceCoordinator({
    this.auditLog,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  bool get isRunning => _active;

  /// Starts one operation and returns immediately with a cancellable handle.
  ///
  /// A second start on this coordinator throws [StateError] while an operation
  /// is active. If an audit log is configured, failure to persist the started
  /// record prevents the executor from running. Failure to persist the
  /// terminal record is exposed as [CompositionLifecycleStorageMaintenanceOperationOutcome.auditError].
  CompositionLifecycleStorageMaintenanceHandle start({
    required String operationId,
    required CompositionLifecycleStorageMaintenanceRequest request,
    required CompositionLifecycleStorageMaintenanceExecutor execute,
  }) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }
    if (_active) {
      throw StateError('A lifecycle storage maintenance operation is already running.');
    }

    _active = true;
    final requestedAt = _clock().toUtc();
    final cancellation = CompositionLifecycleStorageMaintenanceCancellation();
    final completer =
        Completer<CompositionLifecycleStorageMaintenanceOperationOutcome>();

    Future<void>.microtask(() async {
      try {
        final outcome = await _run(
          operationId: operationId,
          request: request,
          execute: execute,
          cancellation: cancellation,
          requestedAt: requestedAt,
        );
        completer.complete(outcome);
      } on Object catch (error) {
        final now = _clock().toUtc();
        completer.complete(
          CompositionLifecycleStorageMaintenanceOperationOutcome(
            operationId: operationId,
            status: CompositionLifecycleStorageMaintenanceOperationStatus.failed,
            startedAt: requestedAt,
            completedAt: now,
            error: error.toString(),
            cancellationRequested: cancellation.isCancellationRequested,
          ),
        );
      } finally {
        _active = false;
      }
    });

    return CompositionLifecycleStorageMaintenanceHandle._(
      cancellation: cancellation,
      outcome: completer.future,
    );
  }

  Future<CompositionLifecycleStorageMaintenanceOperationOutcome> _run({
    required String operationId,
    required CompositionLifecycleStorageMaintenanceRequest request,
    required CompositionLifecycleStorageMaintenanceExecutor execute,
    required CompositionLifecycleStorageMaintenanceCancellation cancellation,
    required DateTime requestedAt,
  }) async {
    final startedAt = _clock().toUtc();
    final startedRecord = CompositionLifecycleStorageMaintenanceOperationRecord(
      operationId: operationId,
      status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
      requestedAt: requestedAt,
      startedAt: startedAt,
      request: request,
    );

    try {
      await auditLog?.append(startedRecord);
    } on Object catch (error) {
      final completedAt = _clock().toUtc();
      return CompositionLifecycleStorageMaintenanceOperationOutcome(
        operationId: operationId,
        status: CompositionLifecycleStorageMaintenanceOperationStatus.failed,
        startedAt: startedAt,
        completedAt: completedAt,
        error: 'Maintenance audit start record could not be persisted.',
        auditError: error.toString(),
        cancellationRequested: cancellation.isCancellationRequested,
      );
    }

    CompositionLifecycleStorageMaintenanceOperationStatus status;
    CompositionLifecycleStorageMaintenanceResult? result;
    String? error;
    if (cancellation.isCancellationRequested) {
      status = CompositionLifecycleStorageMaintenanceOperationStatus.cancelled;
      error = 'Cancelled before the maintenance executor started.';
    } else {
      try {
        result = await execute(request, cancellation);
        status = result.partial
            ? CompositionLifecycleStorageMaintenanceOperationStatus.partial
            : CompositionLifecycleStorageMaintenanceOperationStatus.succeeded;
      } on Object catch (executionError) {
        status = CompositionLifecycleStorageMaintenanceOperationStatus.failed;
        error = executionError.toString();
      }
    }

    final completedAt = _clock().toUtc();
    final terminalRecord = CompositionLifecycleStorageMaintenanceOperationRecord(
      operationId: operationId,
      status: status,
      requestedAt: requestedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      request: request,
      result: result,
      error: error,
    );

    String? auditError;
    try {
      await auditLog?.append(terminalRecord);
    } on Object catch (writeError) {
      auditError = writeError.toString();
    }

    return CompositionLifecycleStorageMaintenanceOperationOutcome(
      operationId: operationId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      result: result,
      error: error,
      auditError: auditError,
      cancellationRequested: cancellation.isCancellationRequested,
    );
  }
}

import 'dart:async';

import 'offline_queue.dart';
import 'sync_context.dart';
import 'sync_operation.dart';
import 'sync_status.dart';

/// Aggregated outcome of a synchronization run.
final class SyncResult {
  final int succeeded;
  final int failed;
  final int conflicts;
  final int skipped;
  final int unauthorized;

  const SyncResult({
    required this.succeeded,
    required this.failed,
    required this.conflicts,
    this.skipped = 0,
    this.unauthorized = 0,
  });

  @override
  String toString() =>
      'SyncResult(succeeded: $succeeded, failed: $failed, '
      'conflicts: $conflicts, skipped: $skipped, unauthorized: $unauthorized)';
}

/// Result of dispatching a single [SyncOperation].
final class DispatchResult {
  final SyncOperationStatus status;
  final String? reason;

  const DispatchResult({required this.status, this.reason});

  const DispatchResult.succeeded()
      : status = SyncOperationStatus.succeeded,
        reason = null;

  const DispatchResult.conflict(this.reason)
      : status = SyncOperationStatus.conflict;

  const DispatchResult.unauthorized(this.reason)
      : status = SyncOperationStatus.unauthorized;

  const DispatchResult.failed(this.reason)
      : status = SyncOperationStatus.failed;

  const DispatchResult.retrying(this.reason)
      : status = SyncOperationStatus.retrying;
}

/// Dispatches an individual [SyncOperation] to the backend.
typedef SyncOperationDispatcher = Future<DispatchResult> Function(
    SyncOperation operation);

/// Orchestrates synchronization with tenant isolation, error classification,
/// and status tracking.
abstract interface class SyncEngine {
  Future<SyncResult> synchronize({SyncContext? context});

  Stream<SyncStatus> get status;
}

/// P12 hardened sync engine.
///
/// Per-operation behavior:
/// - If [SyncContext.isAuthenticated] is `false` → suspend and emit [SyncStatus.authRequired].
/// - If operation org ≠ current org → skip (tenant safety after account switch).
/// - On [SyncOperationStatus.succeeded] → remove from queue.
/// - On [SyncOperationStatus.conflict] → update status, do not retry.
/// - On [SyncOperationStatus.unauthorized] → update status, do not retry.
/// - On [SyncOperationStatus.failed] → update status, do not retry.
/// - On [SyncOperationStatus.retrying] → update attempt count, keep in queue.
final class DefaultSyncEngine implements SyncEngine {
  final OfflineQueue _queue;
  final SyncOperationDispatcher _dispatcher;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  DefaultSyncEngine({
    required OfflineQueue queue,
    required SyncOperationDispatcher dispatcher,
  })  : _queue = queue,
        _dispatcher = dispatcher;

  @override
  Stream<SyncStatus> get status => _statusController.stream;

  @override
  Future<SyncResult> synchronize({SyncContext? context}) async {
    // If not authenticated, suspend sync
    if (context != null && !context.isAuthenticated) {
      _statusController.add(SyncStatus.authRequired);
      return const SyncResult(
          succeeded: 0, failed: 0, conflicts: 0, skipped: 0, unauthorized: 0);
    }

    _statusController.add(SyncStatus.syncing);

    int succeeded = 0;
    int failed = 0;
    int conflicts = 0;
    int skipped = 0;
    int unauthorized = 0;

    try {
      final pendingOps = await _queue.pending();

      for (final op in pendingOps) {
        // Tenant safety: skip ops from a different org context
        if (context != null && !context.canDispatch(op.organizationId)) {
          skipped++;
          continue;
        }

        final updated = op.copyWith(
          status: SyncOperationStatus.syncing,
          attemptCount: op.attemptCount + 1,
          lastAttemptAt: DateTime.now(),
        );
        await _queue.updateStatus(updated);

        try {
          final result = await _dispatcher(updated);

          switch (result.status) {
            case SyncOperationStatus.succeeded:
              await _queue.remove(op.id);
              succeeded++;

            case SyncOperationStatus.conflict:
              await _queue
                  .updateStatus(updated.copyWith(status: SyncOperationStatus.conflict));
              conflicts++;

            case SyncOperationStatus.unauthorized:
              await _queue.updateStatus(
                  updated.copyWith(status: SyncOperationStatus.unauthorized));
              unauthorized++;

            case SyncOperationStatus.failed:
              await _queue
                  .updateStatus(updated.copyWith(status: SyncOperationStatus.failed));
              failed++;

            case SyncOperationStatus.retrying:
              await _queue
                  .updateStatus(updated.copyWith(status: SyncOperationStatus.retrying));
              failed++; // counts against this run

            default:
              failed++;
          }
        } catch (_) {
          await _queue
              .updateStatus(updated.copyWith(status: SyncOperationStatus.retrying));
          failed++;
        }
      }

      final finalStatus =
          (failed > 0 || conflicts > 0 || unauthorized > 0)
              ? SyncStatus.error
              : SyncStatus.idle;
      _statusController.add(finalStatus);

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        skipped: skipped,
        unauthorized: unauthorized,
      );
    } catch (_) {
      _statusController.add(SyncStatus.error);
      rethrow;
    }
  }

  void dispose() => _statusController.close();
}

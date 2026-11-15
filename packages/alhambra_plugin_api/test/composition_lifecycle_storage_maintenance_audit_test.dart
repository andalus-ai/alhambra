import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  final requestedAt = DateTime.utc(2026, 11, 15, 1);
  final startedAt = DateTime.utc(2026, 11, 15, 1, 0, 1);
  final completedAt = DateTime.utc(2026, 11, 15, 1, 0, 5);

  CompositionLifecycleStorageMaintenanceRequest request() =>
      CompositionLifecycleStorageMaintenanceRequest(
        retainFrom: DateTime.utc(2026, 10, 1),
        maxEvents: 500,
        checkpoint: true,
      );

  CompositionLifecycleStorageMaintenanceOperationRecord record({
    required String id,
    required CompositionLifecycleStorageMaintenanceOperationStatus status,
    DateTime? completed,
    CompositionLifecycleStorageMaintenanceRequest? operationRequest,
  }) =>
      CompositionLifecycleStorageMaintenanceOperationRecord(
        operationId: id,
        status: status,
        requestedAt: requestedAt,
        startedAt: startedAt,
        completedAt: completed,
        request: operationRequest ?? request(),
      );

  test('classifies no records as not found', () {
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'missing',
      records: [],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.notFound);
    expect(recovery.requiresReconciliation, isFalse);
    expect(recovery.terminalStatus, isNull);
    expect(recovery.automaticRetryAllowed, isFalse);
  });

  test('classifies a start without terminal record as unknown outcome', () {
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'interrupted',
      records: [
        record(
          id: 'interrupted',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
        ),
      ],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.outcomeUnknown);
    expect(recovery.requiresReconciliation, isTrue);
    expect(recovery.terminalStatus, isNull);
    expect(recovery.automaticRetryAllowed, isFalse);
  });

  test('does not mistake a terminal record without start for completion', () {
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'orphan-terminal',
      records: [
        record(
          id: 'orphan-terminal',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
          completed: completedAt,
        ),
      ],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.incompleteHistory);
    expect(recovery.requiresReconciliation, isTrue);
    expect(recovery.terminalStatus, isNull);
  });

  test('recognizes a matching start and terminal record', () {
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'complete',
      records: [
        record(
          id: 'complete',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
        ),
        // Simulate deserialization: the request is a distinct object with
        // identical values, not the same in-memory instance.
        record(
          id: 'complete',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
          completed: completedAt,
          operationRequest: request(),
        ),
      ],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.completed);
    expect(recovery.requiresReconciliation, isFalse);
    expect(recovery.terminalStatus,
        CompositionLifecycleStorageMaintenanceOperationStatus.succeeded);
    expect(recovery.automaticRetryAllowed, isFalse);
  });

  test('rejects contradictory or duplicate history as conflicting', () {
    final start = record(
      id: 'conflict',
      status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
    );
    final terminal = record(
      id: 'conflict',
      status: CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      completed: completedAt,
    );
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'conflict',
      records: [start, terminal, terminal],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.conflictingHistory);
    expect(recovery.requiresReconciliation, isTrue);
    expect(recovery.terminalStatus, isNull);
  });

  test('detects a terminal record for a different request', () {
    final recovery =
        CompositionLifecycleStorageMaintenanceRecovery.classify(
      operationId: 'changed-request',
      records: [
        record(
          id: 'changed-request',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.started,
        ),
        record(
          id: 'changed-request',
          status: CompositionLifecycleStorageMaintenanceOperationStatus.failed,
          completed: completedAt,
          operationRequest: CompositionLifecycleStorageMaintenanceRequest(
            maxEvents: 100,
          ),
        ),
      ],
    );

    expect(recovery.state,
        CompositionLifecycleStorageMaintenanceRecoveryState.conflictingHistory);
  });

  test('validates the requested operation identifier', () {
    expect(
      () => CompositionLifecycleStorageMaintenanceRecovery.classify(
        operationId: ' ',
        records: [],
      ),
      throwsArgumentError,
    );
  });
}

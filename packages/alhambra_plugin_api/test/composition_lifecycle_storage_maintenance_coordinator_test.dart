import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  final request = CompositionLifecycleStorageMaintenanceRequest(
    maxEvents: 100,
    checkpoint: true,
  );

  CompositionLifecycleStorageMaintenanceResult result({
    List<String> warnings = const [],
  }) =>
      CompositionLifecycleStorageMaintenanceResult(
        startedAt: DateTime.utc(2026, 11, 15),
        completedAt: DateTime.utc(2026, 11, 15, 0, 0, 1),
        recordsRemoved: 3,
        checkpointRequested: true,
        checkpointCompleted: true,
        warnings: warnings,
      );

  test('writes started and terminal audit records around execution', () async {
    final records = <CompositionLifecycleStorageMaintenanceOperationRecord>[];
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator(
      auditLog: _MemoryAuditLog(records),
      clock: () => DateTime.utc(2026, 11, 15),
    );
    var executed = false;

    final handle = coordinator.start(
      operationId: 'maintenance-1',
      request: request,
      execute: (request, cancellation) async {
        executed = true;
        return result();
      },
    );
    final outcome = await handle.outcome;

    expect(executed, isTrue);
    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.succeeded);
    expect(outcome.succeeded, isTrue);
    expect(records.map((record) => record.status), [
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
    ]);
    expect(records.last.result!.recordsRemoved, 3);
    expect(coordinator.isRunning, isFalse);
  });

  test('rejects overlapping operations on the same coordinator', () async {
    final gate = Completer<CompositionLifecycleStorageMaintenanceResult>();
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator();
    final first = coordinator.start(
      operationId: 'first',
      request: request,
      execute: (request, cancellation) => gate.future,
    );

    expect(coordinator.isRunning, isTrue);
    expect(
      () => coordinator.start(
        operationId: 'second',
        request: request,
        execute: (request, cancellation) async => result(),
      ),
      throwsStateError,
    );

    gate.complete(result());
    await first.outcome;
    expect(coordinator.isRunning, isFalse);
  });

  test('cancellation before executor start prevents execution', () async {
    final records = <CompositionLifecycleStorageMaintenanceOperationRecord>[];
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator(
      auditLog: _MemoryAuditLog(records),
    );
    var executed = false;

    final handle = coordinator.start(
      operationId: 'cancel-before-start',
      request: request,
      execute: (request, cancellation) async {
        executed = true;
        return result();
      },
    );
    handle.cancel();
    final outcome = await handle.outcome;

    expect(executed, isFalse);
    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.cancelled);
    expect(outcome.cancellationRequested, isTrue);
    expect(records.last.status, CompositionLifecycleStorageMaintenanceOperationStatus.cancelled);
  });

  test('exposes cooperative cancellation while executor is running', () async {
    final entered = Completer<void>();
    final gate = Completer<CompositionLifecycleStorageMaintenanceResult>();
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator();

    final handle = coordinator.start(
      operationId: 'cancel-running',
      request: request,
      execute: (request, cancellation) async {
        entered.complete();
        await gate.future;
        expect(cancellation.isCancellationRequested, isTrue);
        return result(warnings: ['Stopped at a safe boundary.']);
      },
    );
    await entered.future;
    handle.cancel();
    gate.complete(result(warnings: ['Stopped at a safe boundary.']));
    final outcome = await handle.outcome;

    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.partial);
    expect(outcome.cancellationRequested, isTrue);
  });

  test('does not execute when the started audit record cannot be persisted', () async {
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator(
      auditLog: _FailingAuditLog(),
    );
    var executed = false;

    final outcome = await coordinator
        .start(
          operationId: 'audit-failure',
          request: request,
          execute: (request, cancellation) async {
            executed = true;
            return result();
          },
        )
        .outcome;

    expect(executed, isFalse);
    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.failed);
    expect(outcome.auditError, contains('audit unavailable'));
  });

  test('surfaces terminal audit failures without hiding execution outcome', () async {
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator(
      auditLog: _FailOnTerminalAuditLog(),
    );

    final outcome = await coordinator
        .start(
          operationId: 'terminal-audit-failure',
          request: request,
          execute: (request, cancellation) async => result(),
        )
        .outcome;

    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.succeeded);
    expect(outcome.auditError, contains('terminal audit unavailable'));
  });

  test('captures executor failures as failed outcomes', () async {
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator();

    final outcome = await coordinator
        .start(
          operationId: 'executor-failure',
          request: request,
          execute: (request, cancellation) async => throw StateError('disk failure'),
        )
        .outcome;

    expect(outcome.status, CompositionLifecycleStorageMaintenanceOperationStatus.failed);
    expect(outcome.error, contains('disk failure'));
  });

  test('validates operation identifiers', () {
    final coordinator = CompositionLifecycleStorageMaintenanceCoordinator();
    expect(
      () => coordinator.start(
        operationId: ' ',
        request: request,
        execute: (request, cancellation) async => result(),
      ),
      throwsArgumentError,
    );
  });
}

final class _MemoryAuditLog
    implements CompositionLifecycleStorageMaintenanceAuditLog {
  final List<CompositionLifecycleStorageMaintenanceOperationRecord> records;

  _MemoryAuditLog(this.records);

  @override
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  ) async {
    records.add(record);
  }
}

final class _FailingAuditLog
    implements CompositionLifecycleStorageMaintenanceAuditLog {
  @override
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  ) async {
    throw StateError('audit unavailable');
  }
}

final class _FailOnTerminalAuditLog
    implements CompositionLifecycleStorageMaintenanceAuditLog {
  int writes = 0;

  @override
  Future<void> append(
    CompositionLifecycleStorageMaintenanceOperationRecord record,
  ) async {
    writes++;
    if (writes > 1) throw StateError('terminal audit unavailable');
  }
}

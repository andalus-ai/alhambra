import 'dart:io';

import 'package:alhambra_lifecycle_sqlite_store/alhambra_lifecycle_sqlite_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late SqliteCompositionLifecycleEventStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-maintenance-audit-sqlite-');
    store = SqliteCompositionLifecycleEventStore.open(
      path: '${directory.path}/maintenance.sqlite',
    );
  });

  tearDown(() async {
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  final requestedAt = DateTime.utc(2026, 11, 15, 2);
  final startedAt = DateTime.utc(2026, 11, 15, 2, 0, 1);

  CompositionLifecycleStorageMaintenanceOperationRecord record(
    String id,
    CompositionLifecycleStorageMaintenanceOperationStatus status, {
    DateTime? completedAt,
    int maxEvents = 100,
  }) =>
      CompositionLifecycleStorageMaintenanceOperationRecord(
        operationId: id,
        status: status,
        requestedAt: requestedAt,
        startedAt: startedAt,
        completedAt: completedAt,
        request: CompositionLifecycleStorageMaintenanceRequest(maxEvents: maxEvents),
        result: status == CompositionLifecycleStorageMaintenanceOperationStatus.started
            ? null
            : CompositionLifecycleStorageMaintenanceResult(
                startedAt: startedAt,
                completedAt: completedAt!,
                recordsRemoved: 4,
                checkpointRequested: false,
              ),
      );

  test('creates the maintenance audit migration', () {
    expect(
      store.database.select('PRAGMA user_version').single['user_version'],
      SqliteCompositionLifecycleEventStore.schemaVersion,
    );
    expect(
      store.database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'lifecycle_maintenance_audit'",
      ),
      isNotEmpty,
    );
  });

  test('persists audit records across database reopen', () async {
    await store.append(record(
      'sqlite-op',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    ));
    await store.append(record(
      'sqlite-op',
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      completedAt: startedAt.add(const Duration(seconds: 1)),
    ));
    final path = '${directory.path}/maintenance.sqlite';
    await store.close();
    store = SqliteCompositionLifecycleEventStore.open(path: path);

    final records = await store.query(
      CompositionLifecycleStorageMaintenanceAuditQuery(operationId: 'sqlite-op'),
    );
    expect(records.map((value) => value.status), [
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
    ]);
    expect(records.last.result!.recordsRemoved, 4);
  });

  test('makes identical appends idempotent and rejects conflicting reuse', () async {
    final start = record(
      'idempotent',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    );
    await store.append(start);
    await store.append(start);
    expect(
      (await store.query(CompositionLifecycleStorageMaintenanceAuditQuery())).length,
      1,
    );
    expect(
      () => store.append(record(
        'idempotent',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
        maxEvents: 999,
      )),
      throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
    );
  });

  test('enforces a single terminal record and supports keyset pagination', () async {
    for (final id in ['d', 'b', 'a', 'c']) {
      await store.append(record(
        id,
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
      ));
    }
    final first = await store.query(CompositionLifecycleStorageMaintenanceAuditQuery(limit: 2));
    expect(first.map((value) => value.operationId), ['a', 'b']);
    final next = await store.query(CompositionLifecycleStorageMaintenanceAuditQuery(
      after: CompositionLifecycleStorageMaintenanceAuditCursor(
        startedAt: startedAt,
        operationId: first.last.operationId,
        status: first.last.status,
      ),
      limit: 2,
    ));
    expect(next.map((value) => value.operationId), ['c', 'd']);

    await store.append(record(
      'a',
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      completedAt: startedAt.add(const Duration(seconds: 2)),
    ));
    expect(
      () => store.append(record(
        'a',
        CompositionLifecycleStorageMaintenanceOperationStatus.failed,
        completedAt: startedAt.add(const Duration(seconds: 3)),
      )),
      throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
    );
  });
}

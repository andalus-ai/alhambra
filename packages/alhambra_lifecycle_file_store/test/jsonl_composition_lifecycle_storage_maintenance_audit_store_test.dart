import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late JsonlCompositionLifecycleStorageMaintenanceAuditStore store;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-maintenance-audit-jsonl-');
    file = File('${directory.path}/audit/maintenance.jsonl');
    store = JsonlCompositionLifecycleStorageMaintenanceAuditStore(file: file);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  final requestedAt = DateTime.utc(2026, 11, 15, 1);
  final startedAt = DateTime.utc(2026, 11, 15, 1, 0, 1);

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
        request: CompositionLifecycleStorageMaintenanceRequest(
          maxEvents: maxEvents,
        ),
        result: status == CompositionLifecycleStorageMaintenanceOperationStatus.started
            ? null
            : CompositionLifecycleStorageMaintenanceResult(
                startedAt: startedAt,
                completedAt: completedAt!,
                recordsRemoved: 2,
                checkpointRequested: false,
              ),
      );

  test('persists and reopens start and terminal audit records', () async {
    final start = record(
      'op-1',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    );
    final terminal = record(
      'op-1',
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      completedAt: startedAt.add(const Duration(seconds: 2)),
    );
    await store.append(start);
    await store.append(terminal);

    final reopened = JsonlCompositionLifecycleStorageMaintenanceAuditStore(file: file);
    final records = await reopened.query(
      CompositionLifecycleStorageMaintenanceAuditQuery(operationId: 'op-1'),
    );
    expect(records.map((value) => value.status), [
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
    ]);
    expect(records.last.result!.recordsRemoved, 2);
  });

  test('identical appends are idempotent and conflicting payloads fail', () async {
    final start = record(
      'op-2',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    );
    await store.append(start);
    await store.append(start);
    expect((await file.readAsLines()).length, 1);

    expect(
      () => store.append(record(
        'op-2',
        CompositionLifecycleStorageMaintenanceOperationStatus.started,
        maxEvents: 200,
      )),
      throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
    );
  });

  test('rejects a second terminal outcome for one operation', () async {
    await store.append(record(
      'op-3',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    ));
    await store.append(record(
      'op-3',
      CompositionLifecycleStorageMaintenanceOperationStatus.succeeded,
      completedAt: startedAt.add(const Duration(seconds: 1)),
    ));
    expect(
      () => store.append(record(
        'op-3',
        CompositionLifecycleStorageMaintenanceOperationStatus.failed,
        completedAt: startedAt.add(const Duration(seconds: 2)),
      )),
      throwsA(isA<CompositionLifecycleStorageMaintenanceAuditIdentityConflictException>()),
    );
  });

  test('queries with filters and a stable exclusive cursor', () async {
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
    final filtered = await store.query(CompositionLifecycleStorageMaintenanceAuditQuery(
      operationId: 'c',
      from: startedAt,
      to: startedAt,
    ));
    expect(filtered.single.operationId, 'c');
  });

  test('discards an interrupted trailing fragment before next append', () async {
    await store.append(record(
      'valid',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    ));
    await file.writeAsString('{"partial":', mode: FileMode.append);
    final recovered = record(
      'recovered',
      CompositionLifecycleStorageMaintenanceOperationStatus.started,
    );
    await store.append(recovered);
    final reopened = JsonlCompositionLifecycleStorageMaintenanceAuditStore(file: file);
    expect(
      (await reopened.query(CompositionLifecycleStorageMaintenanceAuditQuery()))
          .map((value) => value.operationId),
      ['valid', 'recovered'],
    );
    expect(await file.readAsString(), isNot(contains('partial')));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final class _OutboxInspectionStore
    implements PluginRevocationOutboxInspectionStore {
  final List<PluginRevocationOutboxMessage> messages;
  var reads = 0;

  _OutboxInspectionStore(this.messages);

  @override
  Future<List<PluginRevocationOutboxMessage>> readAllOutbox() async {
    reads++;
    return List.unmodifiable(messages);
  }
}

final class _OperatorActionStore
    implements PluginRevocationOperatorActionInspectionStore {
  final List<PluginRevocationOperatorAction> actions;
  var reads = 0;

  _OperatorActionStore(this.actions);

  @override
  Future<List<PluginRevocationOperatorAction>> readOperatorActions() async {
    reads++;
    return List.unmodifiable(actions);
  }
}

final class _ScopeResolver
    implements PluginRevocationOperationsScopeResolver {
  @override
  Future<String?> resolveJournalScope(
    PluginRevocationJournalEntry entry,
  ) async => entry.pluginId.endsWith('-blue') ? 'tenant-blue' : 'tenant-red';

  @override
  Future<String?> resolveOutboxScope(
    PluginRevocationOutboxMessage message,
  ) async => message.event.pluginId.endsWith('-blue')
      ? 'tenant-blue'
      : 'tenant-red';
}

final class _Authorizer implements PluginRevocationOperationsAuthorizer {
  final bool allowed;
  var calls = 0;

  _Authorizer(this.allowed);

  @override
  Future<bool> canInspect({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    calls++;
    return allowed;
  }
}

PluginRevocationJournalEntry _journal(String suffix) =>
    PluginRevocationJournalEntry(
      idempotencyKey: 'key-$suffix',
      operationId: 'operation-$suffix',
      pluginId: 'plugin-$suffix',
      providerOwnerId: 'provider-$suffix',
      action: CapabilityImpactAction.deactivate,
      status: PluginRevocationJournalStatus.pending,
      revision: 1,
      createdAt: DateTime.utc(2026, 11, 14, 10),
      updatedAt: DateTime.utc(2026, 11, 14, 10),
    );

PluginRevocationOutboxMessage _message(String suffix) {
  final at = DateTime.utc(2026, 11, 14, 10);
  return PluginRevocationOutboxMessage(
    event: PluginRevocationAuditEvent(
      eventId: 'event-$suffix',
      idempotencyKey: 'event-key-$suffix',
      operationId: 'operation-$suffix',
      pluginId: 'plugin-$suffix',
      providerOwnerId: 'provider-$suffix',
      action: 'deactivate',
      outcome: 'completed',
      occurredAt: at,
    ),
    state: PluginRevocationOutboxState.pending,
    attempts: 0,
    nextAttemptAt: at,
  );
}

PluginRevocationOperatorAction _action({
  required String id,
  required String scope,
}) =>
    PluginRevocationOperatorAction(
      actionId: id,
      actorId: 'operator-1',
      scopeId: scope,
      reason: 'Approved operational replay',
      approvalReference: 'change-$id',
      targetEventId: 'source-$id',
      replayEventId: 'replay-$id',
      replayGeneration: 1,
      occurredAt: DateTime.utc(2026, 11, 14, 11),
    );

void main() {
  final principal =
      PluginRevocationOperationsPrincipal(actorId: 'operator-1');
  final capturedAt = DateTime.utc(2026, 11, 14, 12);

  test('returns only records owned by the authorized scope', () async {
    final journal = InMemoryPluginRevocationJournalStore();
    await journal.insertIfAbsent(_journal('one-blue'));
    await journal.insertIfAbsent(_journal('two-red'));
    final outbox = _OutboxInspectionStore([
      _message('one-blue'),
      _message('two-red'),
    ]);
    final actionStore = _OperatorActionStore([
      _action(id: 'blue-action', scope: 'tenant-blue'),
      _action(id: 'red-action', scope: 'tenant-red'),
    ]);
    final audit = InMemoryPluginRevocationOperationsAccessAuditStore();
    final authorizer = _Authorizer(true);
    final service = PluginRevocationAdminOperationsService(
      operations: PluginRevocationOperationsService(
        journalStore: journal,
        outboxStore: outbox,
        clock: () => capturedAt,
      ),
      operatorActionStore: actionStore,
      scopeResolver: _ScopeResolver(),
      authorizer: authorizer,
      accessAuditStore: audit,
      clock: () => capturedAt,
    );

    final result = await service.inspect(
      principal: principal,
      scopeId: 'tenant-blue',
    );

    expect(result.scopeId, 'tenant-blue');
    expect(result.operations.journalEntries, hasLength(1));
    expect(result.operations.journalEntries.single.pluginId, 'plugin-one-blue');
    expect(result.operations.outboxMessages, hasLength(1));
    expect(result.operations.outboxMessages.single.event.pluginId,
        'plugin-one-blue');
    expect(result.operations.unresolvedJournalEntries, 1);
    expect(result.operations.pendingOutboxMessages, 1);
    expect(result.operatorActions, hasLength(1));
    expect(result.operatorActions.single.actionId, 'blue-action');
    expect(authorizer.calls, 1);
    expect(audit.records, hasLength(1));
    expect(audit.records.single.decision,
        PluginRevocationOperationsAccessDecision.allowed);
    expect(audit.records.single.scopeId, 'tenant-blue');
  });

  test('audits denied access and reads no operational data', () async {
    final journal = InMemoryPluginRevocationJournalStore();
    final outbox = _OutboxInspectionStore([]);
    final actionStore = _OperatorActionStore([]);
    final audit = InMemoryPluginRevocationOperationsAccessAuditStore();
    final authorizer = _Authorizer(false);
    final service = PluginRevocationAdminOperationsService(
      operations: PluginRevocationOperationsService(
        journalStore: journal,
        outboxStore: outbox,
        clock: () => capturedAt,
      ),
      operatorActionStore: actionStore,
      scopeResolver: _ScopeResolver(),
      authorizer: authorizer,
      accessAuditStore: audit,
      clock: () => capturedAt,
    );

    await expectLater(
      service.inspect(principal: principal, scopeId: 'tenant-red'),
      throwsA(isA<PluginRevocationOperationsAccessDeniedException>()),
    );

    expect(authorizer.calls, 1);
    expect(audit.records, hasLength(1));
    expect(audit.records.single.decision,
        PluginRevocationOperationsAccessDecision.denied);
    expect(audit.records.single.denialCode,
        'operations_inspection_denied');
    expect(outbox.reads, 0);
    expect(actionStore.reads, 0);
  });

  test('rejects an empty scope before authorization', () async {
    final audit = InMemoryPluginRevocationOperationsAccessAuditStore();
    final authorizer = _Authorizer(true);
    final service = PluginRevocationAdminOperationsService(
      operations: PluginRevocationOperationsService(
        journalStore: InMemoryPluginRevocationJournalStore(),
        outboxStore: _OutboxInspectionStore([]),
      ),
      operatorActionStore: _OperatorActionStore([]),
      scopeResolver: _ScopeResolver(),
      authorizer: authorizer,
      accessAuditStore: audit,
    );

    expect(
      () => service.inspect(principal: principal, scopeId: ' '),
      throwsArgumentError,
    );
    expect(authorizer.calls, 0);
    expect(audit.records, isEmpty);
  });
}

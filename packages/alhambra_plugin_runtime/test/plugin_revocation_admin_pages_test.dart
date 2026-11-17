import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final class _Authorizer implements PluginRevocationOperationsAuthorizer {
  final List<String> events;
  final bool allowed;

  _Authorizer(this.events, {this.allowed = true});

  @override
  Future<bool> canInspect({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    events.add('authorize:$scopeId');
    return allowed;
  }
}

final class _PageStore implements PluginRevocationScopedQueryStore {
  final List<String> events;

  _PageStore(this.events);

  PluginRevocationScopedPage<T> _page<T>() => PluginRevocationScopedPage<T>(
        items: const [],
        nextCursor: null,
        snapshotAt: DateTime.utc(2026, 11, 17),
      );

  @override
  Future<PluginRevocationScopedPage<PluginRevocationJournalEntry>>
      queryJournalPage(PluginRevocationJournalPageQuery query) async {
    events.add('query:journal:${query.scopeId}');
    return _page();
  }

  @override
  Future<PluginRevocationScopedPage<PluginRevocationOutboxMessage>>
      queryOutboxPage(PluginRevocationOutboxPageQuery query) async {
    events.add('query:outbox:${query.scopeId}');
    return _page();
  }

  @override
  Future<PluginRevocationScopedPage<PluginRevocationOperatorAction>>
      queryOperatorActionPage(
    PluginRevocationOperatorActionPageQuery query,
  ) async {
    events.add('query:operatorActions:${query.scopeId}');
    return _page();
  }
}

final class _AuditStore
    implements PluginRevocationOperationsAccessAuditStore {
  final List<String> events;
  final List<PluginRevocationOperationsAccessAudit> records = [];

  _AuditStore(this.events);

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    events.add('audit:${audit.resource}');
    records.add(audit);
  }
}

final class _FailingAuditStore
    implements PluginRevocationOperationsAccessAuditStore {
  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    throw StateError('audit persistence failed');
  }
}

void main() {
  const scope = 'workspace-blue';
  final principal =
      PluginRevocationOperationsPrincipal(actorId: 'operator-7');

  test('journal page authorizes and durably audits before querying', () async {
    final events = <String>[];
    final audit = _AuditStore(events);
    final service = PluginRevocationAdminPageService(
      authorizer: _Authorizer(events),
      accessAuditStore: audit,
      queryStore: _PageStore(events),
      clock: () => DateTime.utc(2026, 11, 17, 8),
    );

    final result = await service.journalPage(
      principal: principal,
      query: PluginRevocationJournalPageQuery(
        scopeId: scope,
        pageSize: 25,
        statuses: {PluginRevocationJournalStatus.pending},
      ),
    );

    expect(result.scopeId, scope);
    expect(result.resource, PluginRevocationAdminPageResource.journal);
    expect(result.page.items, isEmpty);
    expect(events, [
      'authorize:$scope',
      'audit:journal',
      'query:journal:$scope',
    ]);
    expect(audit.records.single.pageSize, 25);
    expect(audit.records.single.continuationRequested, isFalse);
    expect(audit.records.single.queryFingerprint, isNotEmpty);
  });

  test('denied scope is audited and never queried', () async {
    final events = <String>[];
    final audit = _AuditStore(events);
    final service = PluginRevocationAdminPageService(
      authorizer: _Authorizer(events, allowed: false),
      accessAuditStore: audit,
      queryStore: _PageStore(events),
    );

    await expectLater(
      service.outboxPage(
        principal: principal,
        query: PluginRevocationOutboxPageQuery(scopeId: scope),
      ),
      throwsA(isA<PluginRevocationOperationsAccessDeniedException>()),
    );

    expect(events, ['authorize:$scope', 'audit:outbox']);
    expect(audit.records.single.decision,
        PluginRevocationOperationsAccessDecision.denied);
    expect(audit.records.single.denialCode,
        'operations_page_inspection_denied');
  });

  test('audit persistence failure prevents the page query', () async {
    final events = <String>[];
    final service = PluginRevocationAdminPageService(
      authorizer: _Authorizer(events),
      accessAuditStore: _FailingAuditStore(),
      queryStore: _PageStore(events),
    );

    await expectLater(
      service.operatorActionPage(
        principal: principal,
        query: PluginRevocationOperatorActionPageQuery(scopeId: scope),
      ),
      throwsStateError,
    );
    expect(events, ['authorize:$scope']);
  });

  test('missing scoped-query adapter fails closed after auditing', () async {
    final events = <String>[];
    final audit = _AuditStore(events);
    final service = PluginRevocationAdminPageService(
      authorizer: _Authorizer(events),
      accessAuditStore: audit,
      queryStore: null,
    );

    await expectLater(
      service.journalPage(
        principal: principal,
        query: PluginRevocationJournalPageQuery(scopeId: scope),
      ),
      throwsA(isA<PluginRevocationScopedQueryUnavailableException>()),
    );
    expect(events, ['authorize:$scope', 'audit:journal']);
    expect(audit.records, hasLength(1));
  });

  test('outbox and operator-action methods use distinct query families',
      () async {
    final events = <String>[];
    final audit = _AuditStore(events);
    final service = PluginRevocationAdminPageService(
      authorizer: _Authorizer(events),
      accessAuditStore: audit,
      queryStore: _PageStore(events),
    );

    await service.outboxPage(
      principal: principal,
      query: PluginRevocationOutboxPageQuery(
        scopeId: scope,
        states: {PluginRevocationOutboxState.deadLetter},
        cursor: 'opaque-next-page',
      ),
    );
    await service.operatorActionPage(
      principal: principal,
      query: PluginRevocationOperatorActionPageQuery(scopeId: scope),
    );

    expect(events, [
      'authorize:$scope',
      'audit:outbox',
      'query:outbox:$scope',
      'authorize:$scope',
      'audit:operatorActions',
      'query:operatorActions:$scope',
    ]);
    expect(audit.records.first.continuationRequested, isTrue);
    expect(audit.records.last.continuationRequested, isFalse);
  });
}

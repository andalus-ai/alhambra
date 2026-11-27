import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final class _Authorizer implements PluginRevocationAccessAuditAuthorizer {
  final List<String> events;
  final bool allowed;

  _Authorizer(this.events, {this.allowed = true});

  @override
  Future<bool> canInspectAccessAudit({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    events.add('authorize:$scopeId');
    return allowed;
  }
}

final class _AuditSink implements PluginRevocationOperationsAccessAuditStore {
  final List<String> events;
  final List<PluginRevocationOperationsAccessAudit> records = [];
  bool fail = false;

  _AuditSink(this.events);

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    events.add('append:${audit.resource}');
    if (fail) throw StateError('audit write failed');
    records.add(audit);
  }
}

final class _AuditReader
    implements PluginRevocationOperationsAccessAuditInspectionStore {
  final List<String> events;
  final List<PluginRevocationOperationsAccessAudit> result;
  String? scope;
  int? limit;
  DateTime? fromInclusive;
  DateTime? toExclusive;

  _AuditReader(this.events, this.result);

  @override
  Future<List<PluginRevocationOperationsAccessAudit>> readAccessAudits({
    required String scopeId,
    int limit = 100,
    DateTime? fromInclusive,
    DateTime? toExclusive,
  }) async {
    events.add('read:$scopeId');
    scope = scopeId;
    this.limit = limit;
    this.fromInclusive = fromInclusive;
    this.toExclusive = toExclusive;
    return result;
  }
}

void main() {
  const scope = 'workspace-red';
  final principal = PluginRevocationOperationsPrincipal(actorId: 'operator-9');

  test('authorizes and audits the audit-log read before querying', () async {
    final events = <String>[];
    final sink = _AuditSink(events);
    final existing = PluginRevocationOperationsAccessAudit(
      actorId: 'operator-3',
      scopeId: scope,
      decision: PluginRevocationOperationsAccessDecision.denied,
      denialCode: 'operations_page_inspection_denied',
      occurredAt: DateTime.utc(2026, 11, 20, 9),
    );
    final reader = _AuditReader(events, [existing]);
    final service = PluginRevocationAccessAuditInspectionService(
      authorizer: _Authorizer(events),
      accessAuditStore: sink,
      inspectionStore: reader,
      clock: () => DateTime.utc(2026, 11, 21, 10),
    );

    final result = await service.inspect(
      principal: principal,
      query: PluginRevocationAccessAuditQuery(
        scopeId: scope,
        limit: 25,
        fromInclusive: DateTime.utc(2026, 11, 1),
        toExclusive: DateTime.utc(2026, 11, 22),
      ),
    );

    expect(result.scopeId, scope);
    expect(result.records, [existing]);
    expect(events, ['authorize:$scope', 'append:accessAudit', 'read:$scope']);
    expect(reader.scope, scope);
    expect(reader.limit, 25);
    expect(reader.fromInclusive, DateTime.utc(2026, 11, 1));
    expect(reader.toExclusive, DateTime.utc(2026, 11, 22));
    expect(sink.records, hasLength(1));
    expect(sink.records.single.decision,
        PluginRevocationOperationsAccessDecision.allowed);
    expect(sink.records.single.resource, 'accessAudit');
    expect(sink.records.single.pageSize, 25);
    expect(sink.records.single.queryFingerprint, hasLength(64));
  });

  test('denied audit-log inspection is recorded and never read', () async {
    final events = <String>[];
    final sink = _AuditSink(events);
    final reader = _AuditReader(events, const []);
    final service = PluginRevocationAccessAuditInspectionService(
      authorizer: _Authorizer(events, allowed: false),
      accessAuditStore: sink,
      inspectionStore: reader,
    );

    await expectLater(
      service.inspect(
        principal: principal,
        query: PluginRevocationAccessAuditQuery(scopeId: scope),
      ),
      throwsA(isA<PluginRevocationOperationsAccessDeniedException>()),
    );

    expect(events, ['authorize:$scope', 'append:accessAudit']);
    expect(sink.records.single.decision,
        PluginRevocationOperationsAccessDecision.denied);
    expect(sink.records.single.denialCode, 'access_audit_inspection_denied');
  });

  test('audit sink failure prevents reading the audit log', () async {
    final events = <String>[];
    final sink = _AuditSink(events)..fail = true;
    final reader = _AuditReader(events, const []);
    final service = PluginRevocationAccessAuditInspectionService(
      authorizer: _Authorizer(events),
      accessAuditStore: sink,
      inspectionStore: reader,
    );

    await expectLater(
      service.inspect(
        principal: principal,
        query: PluginRevocationAccessAuditQuery(scopeId: scope),
      ),
      throwsStateError,
    );
    expect(events, ['authorize:$scope', 'append:accessAudit']);
  });

  test('missing inspection adapter fails closed after auditing', () async {
    final events = <String>[];
    final sink = _AuditSink(events);
    final service = PluginRevocationAccessAuditInspectionService(
      authorizer: _Authorizer(events),
      accessAuditStore: sink,
      inspectionStore: null,
    );

    await expectLater(
      service.inspect(
        principal: principal,
        query: PluginRevocationAccessAuditQuery(scopeId: scope),
      ),
      throwsA(isA<PluginRevocationAccessAuditInspectionUnavailableException>()),
    );
    expect(events, ['authorize:$scope', 'append:accessAudit']);
    expect(sink.records, hasLength(1));
  });

  test('query rejects invalid scope, limits and time ranges', () {
    expect(
      () => PluginRevocationAccessAuditQuery(scopeId: ' '),
      throwsArgumentError,
    );
    expect(
      () => PluginRevocationAccessAuditQuery(scopeId: scope, limit: 201),
      throwsArgumentError,
    );
    expect(
      () => PluginRevocationAccessAuditQuery(
        scopeId: scope,
        fromInclusive: DateTime.utc(2026, 11, 2),
        toExclusive: DateTime.utc(2026, 11, 2),
      ),
      throwsArgumentError,
    );
  });
}

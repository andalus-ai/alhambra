import 'dart:io';

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_revocation_postgres/alhambra_plugin_revocation_postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

final databaseUrl = Platform.environment['ALHAMBRA_TEST_DATABASE_URL'];

void main() {
  final skipReason = databaseUrl == null
      ? 'Set ALHAMBRA_TEST_DATABASE_URL to run PostgreSQL integration tests.'
      : false;

  test('persists scope-isolated access audits and filters by time', () async {
    final pool = Pool.withUrl(databaseUrl!);
    final store = PostgresPluginRevocationAccessAuditStore(pool);
    await store.migrate();
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final scope = 'audit-scope-$suffix';
    addTearDown(pool.close);

    await store.append(PluginRevocationOperationsAccessAudit(
      actorId: 'operator-a',
      scopeId: scope,
      decision: PluginRevocationOperationsAccessDecision.allowed,
      occurredAt: DateTime.utc(2026, 11, 17, 8),
      resource: 'journal',
      pageSize: 25,
      continuationRequested: false,
      queryFingerprint: List<String>.filled(64, 'b').join(),
    ));
    await store.append(PluginRevocationOperationsAccessAudit(
      actorId: 'operator-b',
      scopeId: scope,
      decision: PluginRevocationOperationsAccessDecision.denied,
      denialCode: 'forbidden',
      occurredAt: DateTime.utc(2026, 11, 17, 9),
      resource: 'outbox',
      pageSize: 10,
      continuationRequested: true,
      queryFingerprint: List<String>.filled(64, 'c').join(),
    ));
    await store.append(PluginRevocationOperationsAccessAudit(
      actorId: 'foreign-operator',
      scopeId: 'other-$scope',
      decision: PluginRevocationOperationsAccessDecision.allowed,
      occurredAt: DateTime.utc(2026, 11, 17, 10),
    ));

    final records = await store.readAccessAudits(scopeId: scope);
    expect(records, hasLength(2));
    expect(records.first.actorId, 'operator-b');
    expect(records.first.decision,
        PluginRevocationOperationsAccessDecision.denied);
    expect(records.first.continuationRequested, isTrue);
    expect(records.last.actorId, 'operator-a');
    expect(records.last.queryFingerprint, List<String>.filled(64, 'b').join());

    final bounded = await store.readAccessAudits(
      scopeId: scope,
      fromInclusive: DateTime.utc(2026, 11, 17, 8, 30),
      toExclusive: DateTime.utc(2026, 11, 17, 10),
    );
    expect(bounded, hasLength(1));
    expect(bounded.single.actorId, 'operator-b');

    await expectLater(
      store.readAccessAudits(scopeId: scope, limit: 501),
      throwsArgumentError,
    );

    final verified = await store.verifyAccessAuditChain(scopeId: scope);
    expect(verified.valid, isTrue);
    expect(verified.entriesVerified, 2);
    final foreignChain = await store.verifyAccessAuditChain(
      scopeId: 'other-$scope',
    );
    expect(foreignChain.valid, isTrue);
    expect(foreignChain.entriesVerified, 1);

    await pool.execute(
      'UPDATE alhambra_plugin_revocation_access_audit '
      'SET actor_id = $1 WHERE scope_id = $2 AND actor_id = $3',
      parameters: ['tampered-operator', scope, 'operator-a'],
    );
    final tampered = await store.verifyAccessAuditChain(scopeId: scope);
    expect(tampered.valid, isFalse);
    expect(tampered.failedSequence, 1);

  }, skip: skipReason);
}

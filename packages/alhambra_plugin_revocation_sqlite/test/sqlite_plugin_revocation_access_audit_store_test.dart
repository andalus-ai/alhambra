import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_revocation_sqlite/alhambra_plugin_revocation_sqlite.dart';
import 'package:test/test.dart';

PluginRevocationOperationsAccessAudit _audit({
  required String actor,
  required String scope,
  required DateTime at,
  PluginRevocationOperationsAccessDecision decision =
      PluginRevocationOperationsAccessDecision.allowed,
  String? resource,
  bool? continuation,
}) =>
    PluginRevocationOperationsAccessAudit(
      actorId: actor,
      scopeId: scope,
      decision: decision,
      denialCode: decision == PluginRevocationOperationsAccessDecision.denied
          ? 'forbidden'
          : null,
      occurredAt: at,
      resource: resource,
      pageSize: resource == null ? null : 25,
      continuationRequested: continuation,
      queryFingerprint: resource == null ? null : List<String>.filled(64, 'a').join(),
    );

void main() {
  group('SqlitePluginRevocationAccessAuditStore', () {
    late sq.Database database;
    late SqlitePluginRevocationAccessAuditStore store;

    setUp(() {
      database = sq.sqlite3.openInMemory();
      store = SqlitePluginRevocationAccessAuditStore(database)..migrate();
    });

    tearDown(() => database.dispose());

    test('persists and reads audit records in descending time order', () async {
      await store.append(_audit(
        actor: 'operator-a',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 8),
        resource: 'journal',
      ));
      await store.append(_audit(
        actor: 'operator-b',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 9),
        decision: PluginRevocationOperationsAccessDecision.denied,
        resource: 'outbox',
        continuation: true,
      ));
      await store.append(_audit(
        actor: 'operator-c',
        scope: 'scope-b',
        at: DateTime.utc(2026, 11, 17, 10),
      ));

      final records = await store.readAccessAudits(scopeId: 'scope-a');
      expect(records, hasLength(2));
      expect(records.first.actorId, 'operator-b');
      expect(records.first.decision,
          PluginRevocationOperationsAccessDecision.denied);
      expect(records.first.denialCode, 'forbidden');
      expect(records.first.resource, 'outbox');
      expect(records.first.continuationRequested, isTrue);
      expect(records.last.actorId, 'operator-a');
      expect(records.last.queryFingerprint, List<String>.filled(64, 'a').join());
      expect(records.every((record) => record.scopeId == 'scope-a'), isTrue);
    });

    test('applies half-open time range and limit in SQLite', () async {
      for (var hour = 8; hour < 12; hour++) {
        await store.append(_audit(
          actor: 'operator-$hour',
          scope: 'scope-a',
          at: DateTime.utc(2026, 11, 17, hour),
        ));
      }

      final records = await store.readAccessAudits(
        scopeId: 'scope-a',
        fromInclusive: DateTime.utc(2026, 11, 17, 9),
        toExclusive: DateTime.utc(2026, 11, 17, 11),
        limit: 1,
      );
      expect(records, hasLength(1));
      expect(records.single.actorId, 'operator-10');
    });

    test('verifies independent per-scope hash chains', () async {
      await store.append(_audit(
        actor: 'operator-a',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 8),
      ));
      await store.append(_audit(
        actor: 'operator-b',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 9),
      ));
      await store.append(_audit(
        actor: 'operator-c',
        scope: 'scope-b',
        at: DateTime.utc(2026, 11, 17, 10),
      ));

      final first = await store.verifyAccessAuditChain(scopeId: 'scope-a');
      final second = await store.verifyAccessAuditChain(scopeId: 'scope-b');
      expect(first.valid, isTrue);
      expect(first.entriesVerified, 2);
      expect(first.headHash, isNot(PluginRevocationAccessAuditChainCodec.genesisHash));
      expect(second.valid, isTrue);
      expect(second.entriesVerified, 1);
    });

    test('detects audit-row edits and a rewritten chain head', () async {
      await store.append(_audit(
        actor: 'operator-a',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 8),
      ));
      expect(
        (await store.verifyAccessAuditChain(scopeId: 'scope-a')).valid,
        isTrue,
      );

      database.execute(
        "UPDATE alhambra_plugin_revocation_access_audit "
        "SET actor_id = 'rewritten' WHERE scope_id = 'scope-a'",
      );
      final tampered = await store.verifyAccessAuditChain(scopeId: 'scope-a');
      expect(tampered.valid, isFalse);
      expect(tampered.failedSequence, 1);
    });

    test('detects deletion or alteration of the persisted chain head', () async {
      await store.append(_audit(
        actor: 'operator-a',
        scope: 'scope-a',
        at: DateTime.utc(2026, 11, 17, 8),
      ));
      database.execute(
        "UPDATE alhambra_plugin_revocation_access_audit_chain_head "
        "SET head_hash = 'bad' WHERE scope_id = 'scope-a'",
      );
      final result = await store.verifyAccessAuditChain(scopeId: 'scope-a');
      expect(result.valid, isFalse);
      expect(result.failedSequence, 2);
    });

    test('rejects invalid scope, limit and time range', () async {
      await expectLater(
        store.readAccessAudits(scopeId: ' '),
        throwsArgumentError,
      );
      await expectLater(
        store.readAccessAudits(scopeId: 'scope-a', limit: 501),
        throwsArgumentError,
      );
      await expectLater(
        store.readAccessAudits(
          scopeId: 'scope-a',
          fromInclusive: DateTime.utc(2026, 1, 2),
          toExclusive: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}

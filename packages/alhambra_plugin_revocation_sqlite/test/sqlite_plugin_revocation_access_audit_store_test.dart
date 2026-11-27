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

    test('backfills pre-existing audit rows on first chain migration', () async {
      database.execute(
        'DROP TABLE alhambra_plugin_revocation_access_audit_chain_head',
      );
      database.execute(
        'DROP TABLE alhambra_plugin_revocation_access_audit_chain',
      );
      database.execute('DROP TABLE alhambra_plugin_revocation_access_audit');
      database.execute('''
        CREATE TABLE alhambra_plugin_revocation_access_audit (
          audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
          actor_id TEXT NOT NULL,
          scope_id TEXT NOT NULL,
          decision TEXT NOT NULL,
          denial_code TEXT,
          occurred_at TEXT NOT NULL,
          resource TEXT,
          page_size INTEGER,
          continuation_requested INTEGER,
          query_fingerprint TEXT
        )
      ''');
      database.execute('''
        INSERT INTO alhambra_plugin_revocation_access_audit (
          actor_id, scope_id, decision, occurred_at
        ) VALUES ('legacy-operator', 'legacy-scope', 'allowed',
                  '2026-11-17T08:00:00.000000Z')
      ''');

      final migratedStore = SqlitePluginRevocationAccessAuditStore(database)
        ..migrate();
      final result = await migratedStore.verifyAccessAuditChain(
        scopeId: 'legacy-scope',
      );
      expect(result.valid, isTrue);
      expect(result.entriesVerified, 1);
    });

    test('detects an audit row inserted outside the chained append API', () async {
      database.execute('''
        INSERT INTO alhambra_plugin_revocation_access_audit (
          actor_id, scope_id, decision, occurred_at
        ) VALUES ('bypass', 'scope-a', 'allowed',
                  '2026-11-17T08:00:00.000000Z')
      ''');
      final result = await store.verifyAccessAuditChain(scopeId: 'scope-a');
      expect(result.valid, isFalse);
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

    test('rolls back the audit row when chain persistence fails', () async {
      database.execute('''
        CREATE TRIGGER reject_chain_insert
        BEFORE INSERT ON alhambra_plugin_revocation_access_audit_chain
        BEGIN
          SELECT RAISE(ABORT, 'chain unavailable');
        END
      ''');

      await expectLater(
        store.append(_audit(
          actor: 'operator-a',
          scope: 'scope-a',
          at: DateTime.utc(2026, 11, 17, 8),
        )),
        throwsA(isA<sq.SqliteException>()),
      );

      final auditRows = database.select(
        'SELECT COUNT(*) AS total '
        'FROM alhambra_plugin_revocation_access_audit WHERE scope_id = ?',
        ['scope-a'],
      ).first['total'];
      final chainRows = database.select(
        'SELECT COUNT(*) AS total '
        'FROM alhambra_plugin_revocation_access_audit_chain WHERE scope_id = ?',
        ['scope-a'],
      ).first['total'];
      expect(auditRows, 0);
      expect(chainRows, 0);
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

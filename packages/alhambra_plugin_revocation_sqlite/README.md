# alhambra_plugin_revocation_sqlite

Durable SQLite implementation for Alhambra plugin revocation.

## Responsibilities

- `TransactionalPluginRevocationStore`: atomically create pending execution + journal records and commit terminal execution outcomes + journal revision/status + audit outbox event.
- `PluginRevocationOutboxStore`: claim events using expiring leases, retry scheduling, and lease-token fencing.
- `PluginRevocationOutboxInspectionStore`: read-only `readAllOutbox()` snapshots; inspection never claims or mutates messages.
- `PluginRevocationJournalStore`: revisioned journal reads, insert-if-absent, and compare-and-set updates, exposed through `store.journalStore`.

The adapter is an optional package. The neutral `alhambra_plugin_runtime` package remains database-independent.

The adapter implements `PluginRevocationDeadLetterReplayStore`. Replay inserts a new pending event and operator audit record atomically; it never resets the source dead-letter row.

## Bootstrap

```dart
final persistence = SqlitePluginRevocationStore('/var/lib/app/revocations.sqlite');

final coordinator = PluginRevocationCoordinator(
  manager: pluginManager,
  // Resolve from authenticated host context; never from a request body.
  // The default 'default' scope is retained for single-scope compatibility.
  // scopeId: authenticatedTenantId,
  executionStore: persistence,
  auditSink: persistence,
  approve: approvalPolicy,
);

final journal = JournalBackedPluginRevocationExecutionStore(
  persistence.journalStore,
);

final dispatcher = PluginRevocationOutboxDispatcher(
  store: persistence,
  publisher: auditPublisher,
  workerId: 'audit-outbox-1',
);

await dispatcher.dispatchBatch();
```

Call `close()` when the owning host shuts down.

## Transaction and delivery guarantees

Every mutation is synchronous on the connection and wrapped in `BEGIN IMMEDIATE` / `COMMIT`. SQLite's writer lock serializes write transactions across independent connections. `busy_timeout` is configured to five seconds; callers should still surface and handle lock/busy failures.

The pending execution and initial journal record share one transaction. The terminal execution update, journal status/revision advance, and outbox insert share one transaction. Outbox claims also run in an immediate transaction, preventing two connections from claiming the same due row. A lease token fences stale workers from acknowledging or rescheduling a message after another worker has reclaimed it.

Publishing remains **at least once**, not exactly once. If a process publishes successfully and crashes before marking the row delivered, the event will be published again after lease expiry. The downstream publisher/consumer must deduplicate by `eventId`.

SQLite is intended for embedded, single-host persistence. Use a server database adapter for multi-host deployments. Do not put a live database on object storage or an unreliable network filesystem. The adapter stores sanitized audit details supplied by the runtime; hosts must not put secrets or arbitrary exception messages in those fields.

## Schema

Schema version 1 creates the execution, outbox and journal tables. Schema version 2 adds replay lineage and the operator-action audit table. Schema version 3 adds operator-action `scope_id`. Schema version 4 adds immutable `scope_id` ownership to execution, journal and outbox records plus scope-first inspection indexes. Schema version 5 adds the scope-first operator-action ordering index and normalizes existing journal/outbox/operator timestamps to fixed UTC microsecond text so keyset ordering remains lexically chronological. Each migration runs in a `BEGIN IMMEDIATE` transaction and advances `PRAGMA user_version` only after all changes succeed. Existing databases are upgraded automatically on adapter startup. Rows created before v4 are assigned the explicit compatibility scope `default`.


## Audited dead-letter replay

`replayDeadLetter` only accepts a source row currently in `deadLetter`. It inserts a new pending outbox row and its operator-action audit record in the same immediate transaction. The source row is unchanged. The database writer lock serializes replay generation allocation across independent SQLite connections; unique action IDs make retries idempotent. Each generation has a distinct event ID and idempotency key.

The adapter exposes `readOperatorActions()` for audit inspection. Operator authentication and approval validation remain host responsibilities. SQLite is a single-host persistence option, not a multi-host coordination database.


## Scope ownership

`PluginRevocationCoordinator.execute(scopeId: ...)` accepts a trusted host-resolved scope (defaulting to `default` for source compatibility). The scope is persisted on the execution claim, journal entry and audit outbox event. Terminal completion and journal compare-and-set reject scope changes. Replay verifies that the requested scope matches the source dead-letter event. The adapter does not authenticate or resolve tenant identity; the embedding host must do that before invoking the coordinator.

## Database-native scoped pagination

The adapter implements `PluginRevocationScopedQueryStore`. All three page methods constrain `scope_id`, time bounds, status/state, ordering-timestamp ceiling and keyset cursor in SQL before `LIMIT`; they never call the legacy full-read methods. Ordering is deterministic: journal `(updated_at DESC, idempotency_key DESC)`, outbox `(occurred_at DESC, event_id DESC)`, and operator actions `(occurred_at DESC, action_id DESC)`.

Configure a stable random secret (at least 32 bytes) on every adapter instance:

```dart
final persistence = SqlitePluginRevocationStore(
  '/var/lib/app/revocations.sqlite',
  cursorSecret: cursorSigningSecret,
);
```

The same secret must be shared by all instances serving the same cursor domain and preserved across restarts. Store it in a secret manager; never derive it from a database URL or tenant ID. Without a configured secret, paged queries fail closed. Cursors are HMAC-SHA256 authenticated and bound to query family, scope, filters, time range, and page size. The first page captures an ordering-timestamp ceiling, not a strict insertion or cross-table repeatable-read snapshot. Late-arriving rows with backdated timestamps may become visible during traversal.


## Administrative access audit persistence

`SqlitePluginRevocationAccessAuditStore` implements the runtime access-audit append and scoped inspection contracts. It accepts a caller-owned `sqlite3.Database`; call `migrate()` before passing it to `PluginRevocationAdminPageService` or `PluginRevocationAdminOperationsService`.

```dart
import 'package:sqlite3/sqlite3.dart' as sqlite3;

final auditDb = sqlite3.open('/var/lib/app/revocation-admin-audit.sqlite');
final accessAudits = SqlitePluginRevocationAccessAuditStore(auditDb)
  ..migrate();

final adminPages = PluginRevocationAdminPageService(
  authorizer: hostAuthorizer,
  accessAuditStore: accessAudits,
  queryStore: revocationStore,
);
```

Audit writes use `BEGIN IMMEDIATE` and commit before the service begins the protected inspection query. Reads are scope-filtered in SQL, ordered newest-first with a stable audit-id tie-breaker, and support a half-open time range plus a bounded limit (1–500). The adapter does not own or close the supplied database. Keep this database file and its backups under the same access controls as other security audit data; consider a separate file from the operational revocation store when independent retention or access controls are required.


## Tamper-evident access-audit chain

The adapter also implements the optional
`PluginRevocationAccessAuditChainStore` capability. Each append atomically
writes the audit row, a per-scope SHA-256 chain entry, and the per-scope chain
head under `BEGIN IMMEDIATE`.

```dart
final verification = await accessAudits.verifyAccessAuditChain(
  scopeId: authorizedScopeId,
);
if (!verification.valid) {
  reportAuditIntegrityFailure(verification);
}
```

The first migration that creates the chain tables backfills existing audit
rows in stable audit-ID order. Later migrations do not silently repair a
previously created chain. All new records must be appended through the adapter;
direct audit-table inserts are detected as unchained records. Restrict UPDATE
and DELETE on the audit, chain, and head tables. A local hash chain detects
edits to covered rows but cannot prevent a privileged database operator from
rewriting all local chain state. Use signed external checkpoints or immutable
archival for stronger tamper evidence. See
[Revocation Access-Audit Hash Chain](../../Docs/REVOCATION_ACCESS_AUDIT_HASH_CHAIN.md).

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

Schema version 1 creates the execution, outbox and journal tables. Schema version 2 adds replay lineage columns, a unique source-event/generation index, and the operator-action audit table. The version-2 migration runs in one `BEGIN IMMEDIATE` transaction and records SQLite `user_version = 2` only after all changes succeed. Existing version-1 databases are upgraded automatically on adapter startup.


## Audited dead-letter replay

`replayDeadLetter` only accepts a source row currently in `deadLetter`. It inserts a new pending outbox row and its operator-action audit record in the same immediate transaction. The source row is unchanged. The database writer lock serializes replay generation allocation across independent SQLite connections; unique action IDs make retries idempotent. Each generation has a distinct event ID and idempotency key.

The adapter exposes `readOperatorActions()` for audit inspection. Operator authentication and approval validation remain host responsibilities. SQLite is a single-host persistence option, not a multi-host coordination database.

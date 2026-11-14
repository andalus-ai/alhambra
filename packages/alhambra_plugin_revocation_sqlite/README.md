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

Schema version 1 creates the execution, outbox and journal tables. Version 2 adds replay lineage and the operator-action audit table. Version 3 adds the opaque `scope_id` to operator audit rows. Existing databases are upgraded forward-only; v2 and v3 DDL is applied transactionally. Older audit rows receive the compatibility scope `default`.


## Audited replay and scope

Use `PluginRevocationReplayCommandService` rather than calling the persistence method from an untrusted request handler. The host must supply a principal, authoritative event-scope resolver, authorization adapter and approval verifier. The adapter persists `scopeId` with the actor and approval evidence. SQLite's immediate transaction serializes replay generations.

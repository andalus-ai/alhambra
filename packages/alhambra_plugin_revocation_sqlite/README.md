# alhambra_plugin_revocation_sqlite

Durable SQLite implementation for Alhambra plugin revocation.

## Responsibilities

- `TransactionalPluginRevocationStore`: create pending execution records and atomically commit terminal execution outcomes with their audit outbox event.
- `PluginRevocationOutboxStore`: claim events using expiring leases, retry scheduling, and lease-token fencing.
- `PluginRevocationJournalStore`: revisioned journal reads, insert-if-absent, and compare-and-set updates, exposed through `store.journalStore`.

The adapter is an optional package. The neutral `alhambra_plugin_runtime` package remains database-independent.

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

The terminal execution update and outbox insert share one transaction. Outbox claims also run in an immediate transaction, preventing two connections from claiming the same due row. A lease token fences stale workers from acknowledging or rescheduling a message after another worker has reclaimed it.

Publishing remains **at least once**, not exactly once. If a process publishes successfully and crashes before marking the row delivered, the event will be published again after lease expiry. The downstream publisher/consumer must deduplicate by `eventId`.

SQLite is intended for embedded, single-host persistence. Use a server database adapter for multi-host deployments. Do not put a live database on object storage or an unreliable network filesystem. The adapter stores sanitized audit details supplied by the runtime; hosts must not put secrets or arbitrary exception messages in those fields.

## Schema

Schema version 1 creates `plugin_revocation_execution`, `plugin_revocation_outbox`, and `plugin_revocation_journal`. The outbox has a unique event ID and idempotency key plus an index for due/expired work. The adapter creates tables idempotently and records SQLite `user_version = 1`. Future schema changes must use forward-only migrations and preserve enum names as text rather than ordinal values.

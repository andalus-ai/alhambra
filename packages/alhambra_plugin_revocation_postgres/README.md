# alhambra_plugin_revocation_postgres

PostgreSQL implementation of Alhambra plugin revocation execution, journal and audit outbox contracts.

## Why a separate package?

The core `alhambra_plugin_runtime` package defines the contracts and remains database-neutral. This optional adapter provides multi-instance persistence using PostgreSQL transactions, uniqueness constraints, and row-level worker claims. It also implements the read-only `PluginRevocationOutboxInspectionStore` contract via `readAllOutbox()`; inspection does not claim or mutate messages.

The adapter implements `PluginRevocationDeadLetterReplayStore`. Replay inserts a new pending event and operator audit record atomically; it never resets the source dead-letter row.

## Bootstrap

```dart
import 'package:alhambra_plugin_revocation_postgres/alhambra_plugin_revocation_postgres.dart';

// Run once during deployment with a dedicated migration role.
final migration = PostgresPluginRevocationStore.fromUrl(
  migrationDatabaseUrl,
);
await migration.migrate();
await migration.close();

// Application traffic uses a separate, least-privilege database role.
final persistence = PostgresPluginRevocationStore.fromUrl(
  appDatabaseUrl,
);

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
  workerId: 'revocation-audit-worker-1',
);

await dispatcher.dispatchBatch();

// On graceful shutdown:
await persistence.close();
```

Do not hard-code credentials. Supply the connection URL through a secret manager or deployment environment. Prefer TLS with certificate verification for remote database connections.

## Atomicity

`writePending` inserts the execution record and initial journal entry in one transaction. `completeAndEnqueue` updates the execution record, advances the journal revision/status, and inserts the unique outbox event in one transaction. A missing journal row causes the entire completion transaction to roll back.

The journal view returned by `journalStore` uses the same PostgreSQL pool and schema. Direct journal compare-and-set remains revision-checked.

## Distributed outbox claims

Claiming runs in a transaction. PostgreSQL selects eligible rows with `FOR UPDATE SKIP LOCKED`, then updates their attempt count and lease in the same transaction. Independent workers can claim disjoint batches without a global application lock.

A unique lease token fences stale workers from acknowledging or rescheduling a message after it has been reclaimed. Expired leases at the attempt limit are dead-lettered.

## Delivery semantics

Delivery is **at least once**, not exactly once. A process can publish successfully and crash before recording acknowledgement. The publisher/consumer must deduplicate by the stable event ID.

## Migration and operations

- Migration version 1 is available at `migrations/001_plugin_revocation.sql`; version 2 adds audited replay; version 3 adds the operator `scope_id`. All versions are applied by `migrate()`.
- Run migrations with a dedicated role; grant the application role only the required table and sequence privileges (no sequence is currently used).
- Configure pool size, connection timeout, query timeout, and TLS through the PostgreSQL URL.
- Monitor pending count, oldest pending age, expired leases, retry attempts and dead-letter count using the outbox tables.
- Define retention and archival for delivered/dead-letter rows according to audit policy.
- Keep `detail` sanitized. Never persist credentials, tokens, plugin payloads, raw exception messages or secrets.

## Integration tests

Set `ALHAMBRA_TEST_DATABASE_URL` to a disposable PostgreSQL database and run:

```sh
dart pub get
dart test
```

The integration suite verifies atomic execution/journal/outbox completion, independent-pool claim concurrency, journal revision CAS, and rollback when the journal update cannot be completed. Tests are skipped when the environment variable is absent.


## Audited replay and scope

Use `PluginRevocationReplayCommandService` rather than calling the persistence method from an untrusted request handler. The host supplies an authenticated principal, authoritative event-scope resolver, authorization adapter and approval verifier. The adapter persists `scopeId` with the actor and approval evidence. PostgreSQL serializes action IDs with a transaction-scoped advisory lock and replay generations with a source-row lock.

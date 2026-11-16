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

- Migration versions 1–5 are applied transactionally by `migrate()`. The checked-in SQL migrations are `migrations/001_plugin_revocation.sql`, `migrations/002_audited_dead_letter_replay.sql`, `migrations/003_operator_scope.sql`, `migrations/004_scope_ownership.sql` and `migrations/005_scoped_operator_action_index.sql`. Version 4 adds immutable scope ownership to execution, journal and outbox records and scope-first inspection indexes. Version 5 adds the operator-action scope/order index. Existing rows are assigned the explicit compatibility scope `default`.
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


## Audited dead-letter replay

`replayDeadLetter` verifies and locks the source dead-letter row, allocates a generation, and inserts a new pending outbox event plus its operator-action audit record in one PostgreSQL transaction. A transaction-scoped advisory lock serializes requests using the same action ID; the source row lock serializes distinct approved replays of the same source event. Unique constraints provide a final integrity boundary. The original dead-letter row remains unchanged.

The adapter exposes `readOperatorActions()`. Actor authentication, authorization, tenant scoping and approval-reference validation must be performed by the host before invoking replay. Replay delivery remains at-least-once.


## Scope ownership

`PluginRevocationCoordinator.execute(scopeId: ...)` accepts a trusted host-resolved scope (defaulting to `default` for source compatibility). The scope is persisted on the execution claim, journal entry and audit outbox event. Terminal completion and journal compare-and-set reject scope changes. Replay verifies that the requested scope matches the source dead-letter event. The adapter does not authenticate or resolve tenant identity; the embedding host must do that before invoking the coordinator.

## Database-native scoped pagination

The adapter implements `PluginRevocationScopedQueryStore` for journal, outbox and operator-action history. Scope, time range, status/state, snapshot and cursor predicates are included in the SQL WHERE clause before LIMIT. Keyset order is deterministic with a unique ID tie-breaker. No full-read inspection method is used by the page queries.

Configure a stable random signing secret on every adapter instance:

```dart
final persistence = PostgresPluginRevocationStore.fromUrl(
  appDatabaseUrl,
  cursorSecret: cursorSigningSecret,
);
```

The secret must contain at least 32 bytes, be shared across instances serving the same cursor domain, and survive restarts. Keep it in a secret manager. HMAC-SHA256 cursors bind query family, scope, normalized filters, time range and page size; mismatches and tampering fail closed. The captured snapshot is an insert upper bound, not a serializable cross-table snapshot.

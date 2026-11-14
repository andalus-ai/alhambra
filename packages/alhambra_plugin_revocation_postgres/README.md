# alhambra_plugin_revocation_postgres

PostgreSQL implementation of Alhambra plugin revocation execution, journal and audit outbox contracts.

## Why a separate package?

The core `alhambra_plugin_runtime` package defines the contracts and remains database-neutral. This optional adapter provides multi-instance persistence using PostgreSQL transactions, uniqueness constraints, and row-level worker claims.

## Bootstrap

```dart
import 'package:alhambra_plugin_revocation_postgres/alhambra_plugin_revocation_postgres.dart';

final persistence = PostgresPluginRevocationStore.fromUrl(
  'postgresql://app_user:secret@db.example.com:5432/alhambra'
      '?sslmode=verify-full&max_connection_count=12&connect_timeout=10',
);

// Run migrations using a deployment/migration role before serving traffic.
await persistence.migrate();

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

- Migration version 1 is available at `migrations/001_plugin_revocation.sql` and is also applied by `migrate()`.
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

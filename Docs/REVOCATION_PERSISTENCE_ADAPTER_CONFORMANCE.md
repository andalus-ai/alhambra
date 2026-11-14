# Revocation Persistence Adapter Conformance

Status: behavioral contract and implementation parity review for the optional SQLite and PostgreSQL adapters.

## Boundary

The alhambra_plugin_runtime package owns the persistence contracts and remains database-neutral. Database-specific behavior belongs in optional adapter packages:

- alhambra_plugin_revocation_sqlite for embedded, single-host deployments.
- alhambra_plugin_revocation_postgres for server-backed, multi-worker deployments.

Both adapters implement TransactionalPluginRevocationStore, PluginRevocationJournalStore through journalStore, and PluginRevocationOutboxStore.

## Required conformance matrix

| Contract behavior | SQLite | PostgreSQL |
|---|---|---|
| Pending execution + initial journal | One BEGIN IMMEDIATE transaction | One database transaction |
| Duplicate idempotency key | Insert-if-absent returns false | Unique key + insert-if-absent returns false |
| Terminal execution + journal status/revision + outbox | One BEGIN IMMEDIATE transaction | One database transaction |
| Missing execution row | Reject and roll back | Reject and roll back |
| Missing journal row at completion | Reject and roll back | Reject and roll back |
| Journal compare-and-set | Revision-guarded update | Revision-guarded update |
| Concurrent claims | SQLite writer lock serializes claim transactions | FOR UPDATE SKIP LOCKED |
| Expired lease reclaim | Increment attempts and issue a new token | Increment attempts and issue a new token |
| Stale acknowledgement/reschedule | Lease-token fenced | Lease-token fenced |
| Retry exhaustion | Dead-letter | Dead-letter |
| Delivery semantics | At least once | At least once |

The journal starts at revision 1 with pending status. A successful terminal completion advances it to revision 2 and maps the execution outcome to the corresponding journal status. Further explicit journal reconciliation uses compare-and-set and increments the revision exactly once.

## Safety invariants

1. A pending execution must never exist without its initial journal record.
2. A terminal execution must never commit unless its journal transition and unique outbox insertion also commit.
3. An ambiguous execution remains a reconciliation concern; adapters do not rerun plugin side effects.
4. A reclaimed outbox message receives a new lease token. A previous worker cannot acknowledge or reschedule it.
5. Reaching the configured attempt limit moves the message to deadLetter; it is not silently discarded.
6. Publishing is at-least-once. Consumers must deduplicate by stable eventId.
7. Database adapters persist only sanitized audit detail supplied by the host.

## Test coverage expectations

The adapter suites should exercise:

- Atomic pending execution and journal creation.
- Atomic terminal execution, journal revision/status, and outbox creation.
- Rollback when a required companion row is absent.
- Duplicate idempotency key handling.
- Journal stale-revision rejection.
- Independent worker claim concurrency where supported.
- Expired lease reclaim and stale token fencing.
- Retry exhaustion and dead-letter behavior.

SQLite tests can run with an in-memory database plus a temporary file database for independent-connection behavior. PostgreSQL tests require a disposable server and ALHAMBRA_TEST_DATABASE_URL; they are opt-in.

## Deployment selection

- Use SQLite for embedded, single-host persistence where the database file resides on a filesystem with reliable SQLite locking.
- Use PostgreSQL for multi-host or multi-worker deployments.
- Do not share a live SQLite database over object storage or an unreliable network filesystem.
- Keep migrations separate from normal application startup privileges where deployment policy requires it.
- Treat dead-letter replay and manual reconciliation as explicit, audited operator actions.

## Current validation boundary

The source and tests are committed through the adapter packages. A green conformance result requires running Dart formatting, analysis, the SQLite suite, and PostgreSQL integration tests against a disposable database. Merely adding opt-in tests does not constitute a successful database validation run.

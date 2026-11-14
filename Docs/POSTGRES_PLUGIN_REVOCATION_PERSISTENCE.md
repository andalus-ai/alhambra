# PostgreSQL Plugin Revocation Persistence

Status: implementation added; database integration tests are opt-in and require a PostgreSQL server.

## Package boundary

`alhambra_plugin_revocation_postgres` implements the existing execution, journal and outbox contracts from `alhambra_plugin_runtime`. It is optional and does not add PostgreSQL dependencies to the runtime package.

## Transaction boundaries

| Operation | Transactional writes |
|---|---|
| Claim pending execution | Execution row + initial journal row |
| Complete execution | Execution outcome + journal status/revision + unique outbox event |
| Journal CAS | Revision-guarded journal update |
| Claim outbox | Lock eligible rows with SKIP LOCKED + attempts/lease update |
| Acknowledge | Lease-token-guarded delivered transition |
| Retry | Lease-token-guarded reschedule/dead-letter transition |

The completion transaction intentionally fails if the execution or journal row is missing. This avoids reporting a terminal result while its recovery/audit state is incomplete.

## Multi-worker behavior

PostgreSQL row locks and `SKIP LOCKED` allow concurrent workers to claim different outbox rows. The lease token is unique per claim and is required for acknowledgement/rescheduling. A stale worker therefore cannot overwrite the state established by a later claim.

The adapter provides database-level atomicity, not exactly-once external effects. Publication is at-least-once and requires downstream event-ID deduplication.

## Operational constraints

- Run schema migration before enabling revocation processing.
- Use TLS certificate verification for remote connections.
- Keep database credentials outside source control.
- Use a dedicated migration role and a restricted application role.
- Monitor and retain dead-letter events; replay must remain an explicit operator action.
- Use sanitized audit details only.
- The connection pool is owned by the adapter and is closed by `close()`.

## Validation boundary

The tests use real PostgreSQL and are gated by `ALHAMBRA_TEST_DATABASE_URL`. Unit tests without this variable skip the integration cases. Do not infer database correctness from compilation or in-memory tests alone.

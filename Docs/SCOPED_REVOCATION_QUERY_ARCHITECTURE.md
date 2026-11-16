# Scoped Revocation Query Architecture

## Status

The trusted scope ownership layer is implemented in schema v4. The storage-neutral query contracts and SQLite/PostgreSQL database-native page queries are implemented. The authorized paged admin service remains follow-on work; existing legacy inspection APIs still perform full reads.

## Query invariants

- Scope comes from authenticated host context and is persisted immutably.
- Authorization and durable access auditing happen before any operational query.
- Scope, time, status/state, snapshot and cursor predicates are applied in the database before LIMIT.
- All query values are bound parameters; no scope/filter value is interpolated into SQL.
- Each record family uses a total descending order with a unique tie-breaker:
  - Journal: `(updated_at DESC, idempotency_key DESC)`.
  - Outbox: `(occurred_at DESC, event_id DESC)`.
  - Operator action: `(occurred_at DESC, action_id DESC)`.
- Page size defaults to 50 and is bounded to 200.
- Cursor tokens are opaque and adapter-issued. They must be integrity-protected and bound to query family, scope, normalized filters, time bounds, page size and snapshot boundary.
- A cursor from another scope or query must fail closed. The runtime does not parse or trust cursor contents.

## Runtime contracts

`PluginRevocationScopedQueryStore` is an optional capability. It exposes journal, outbox and operator-action page queries without changing legacy `readAll` APIs. Query DTOs validate scope, time ranges, page size and cursor size. Page results are immutable and include an optional next cursor and a captured `snapshotAt`.

The interface contract explicitly forbids implementing page methods by calling legacy full-read methods and filtering in memory. Adapters that do not implement this capability must not be used by a paged admin endpoint.

## Snapshot semantics

The captured `snapshotAt` is a ceiling on the ordering timestamp, not a stable insertion snapshot. Late-arriving rows with backdated timestamps can become visible during a traversal, and journal status updates can change `updated_at`. Operational browsing accepts this bounded consistency model. Audit exports requiring repeatable reads need a dedicated transaction/export job and must document the database isolation guarantee.

## Delivery sequence

1. [x] Persist immutable scope ownership in execution, journal and outbox records (schema v4).
2. [x] Define storage-neutral bounded scoped query contracts.
3. [x] Implement scope-first keyset SQL in SQLite and PostgreSQL, including indexes and authenticated cursor binding.
4. [ ] Add paged admin inspection with authorization and durable access audit before querying.
5. [x] Add SQLite and PostgreSQL tests for cross-scope isolation, deterministic ordering, cursor misuse, bounds and page boundaries. Late-arriving backdated rows and mutable journal timestamps remain visible consistency limitations; strict audit exports require a database transaction or dedicated export job.
6. [ ] Add optional scope-aware retention as a separate maintenance capability.

Do not expose paged inspection until both durable adapters enforce the scope predicate before LIMIT.

## Cursor signing configuration

Both durable adapters require a stable host-provided `cursorSecret` (minimum 32 bytes) before a page traversal can issue or consume a cursor. Tokens use HMAC-SHA256 and bind the query family, exact scope, normalized status/state filters, time range and page size. The secret must be shared across instances and retained across restarts. An unconfigured adapter fails closed when paged inspection is requested.

SQLite schema v5 adds an operator-action scope/order index and normalizes existing journal/outbox/operator timestamps to fixed-width UTC microsecond text. This is required because SQLite compares the stored timestamp text for index-compatible ordering and cursor predicates.

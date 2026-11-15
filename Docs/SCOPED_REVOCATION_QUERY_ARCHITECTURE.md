# Scoped Revocation Query Architecture

## Status

The trusted scope ownership layer is implemented in schema v4. The storage-neutral query contracts are introduced in this increment. SQLite/PostgreSQL SQL implementations and the authorized paged admin service remain follow-on work; existing inspection APIs still perform full reads.

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

The captured `snapshotAt` is an upper bound for newly inserted records, not a claim of a cross-table serializable snapshot. Journal status updates can change `updated_at` during a traversal. Operational browsing may accept this bounded consistency model. Audit exports requiring repeatable reads need a dedicated transaction/export job and must document the database isolation guarantee.

## Delivery sequence

1. [x] Persist immutable scope ownership in execution, journal and outbox records (schema v4).
2. [x] Define storage-neutral bounded scoped query contracts.
3. [ ] Implement scope-first keyset SQL in SQLite and PostgreSQL, including indexes and cursor binding.
4. [ ] Add paged admin inspection with authorization and durable access audit before querying.
5. [ ] Add adapter integration tests for cross-scope isolation, deterministic ordering, cursor misuse, bounds, page boundaries and concurrent inserts.
6. [ ] Add optional scope-aware retention as a separate maintenance capability.

Do not expose paged inspection until both durable adapters enforce the scope predicate before LIMIT.

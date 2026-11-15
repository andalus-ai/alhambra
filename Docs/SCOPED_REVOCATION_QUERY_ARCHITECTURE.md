# Scoped Revocation Query Architecture

## Status

Implementation design for the next persistence increment. This document is normative for the order of work; it does not claim that database-native scoped pagination is already implemented.

## Why another persistence boundary is required

The current administrative inspection service authorizes a requested scope, reads the complete journal and outbox, and resolves record ownership through host callbacks. This is a safe compatibility boundary for small installations, but it is not a scalable query strategy. Applying a page limit before ownership resolution is unsafe because records belonging to other scopes could consume the page and cause missing or misleading results. Applying the limit after loading all rows is bounded only at the response boundary, not at the database or memory boundary.

A database-native scoped query also cannot safely infer ownership from `pluginId`, `providerOwnerId`, operation names, or caller-provided filter values. Scope must be assigned by a trusted host boundary and persisted with the operation.

## Required invariants

1. **Trusted scope assignment:** a host supplies a validated, non-empty scope identifier from authenticated execution context. The runtime never derives a scope from a plugin ID or request payload.
2. **Immutable ownership:** a journal entry and its terminal outbox event retain the scope assigned when the operation was accepted. Updating status, replaying, or retrying cannot move an existing record to another scope.
3. **Atomic propagation:** the execution claim, journal row, terminal execution update, and outbox event use the same scope value. The transactional adapters must reject a terminal write whose scope differs from the pending row.
4. **Fail closed:** missing scope is not treated as a wildcard. Legacy records receive an explicit compatibility scope during migration and remain distinguishable from newly scoped records.
5. **Authorize before query:** the admin service must complete host authorization and durable access auditing before issuing any scoped database query.
6. **Stable ordering:** every page uses a total order with a unique tie-breaker. Timestamp-only ordering is insufficient.
7. **Opaque continuation:** cursors are versioned, integrity-protected by the host adapter or encoded as opaque server-side tokens, and bound to the scope and normalized filter set. A cursor from one scope or filter cannot be reused for another.
8. **Bounded work:** page size has a conservative maximum. Database queries apply scope, time range, status and cursor predicates before LIMIT.
9. **No implied exactly-once effects:** pagination and snapshot tokens describe reads only; they do not alter outbox delivery semantics.

## Runtime model changes

The next implementation should add an optional-at-construction, normalized `scopeId` to:

- `PluginRevocationExecutionRecord`
- `PluginRevocationJournalEntry`
- `PluginRevocationAuditEvent`
- `PluginRevocationOperatorAction` already has persisted scope ownership

The optional constructor value is a source-compatibility bridge for existing hosts. Durable production adapters must normalize absent values to a configured legacy scope on insert, and must never silently substitute a tenant scope. New scoped deployments should require a non-empty scope in their host execution facade.

`PluginRevocationCoordinator.execute` should accept a trusted optional scope context and carry it unchanged through pending and terminal records. It must not accept scope from individual `CapabilityImpactDecision` values. The host is responsible for authenticating and validating the context before invoking the coordinator.

The SQLite/PostgreSQL adapters must verify the scope on terminal completion against the existing pending execution/journal row. A mismatch must abort the transaction, including the outbox insert.

## Schema migration plan

### SQLite

Advance the schema version from 3 to 4. In one `BEGIN IMMEDIATE` migration:

- add `scope_id TEXT NOT NULL DEFAULT 'default'` to execution, journal and outbox tables;
- backfill existing rows to the configured compatibility scope only if the adapter supports an explicit migration option; otherwise preserve the documented `default` legacy scope;
- create composite indexes beginning with `scope_id` and then the query ordering columns;
- set `PRAGMA user_version = 4` before commit.

SQLite does not support adding a non-constant expression as a column default. Use a stable literal default and bind all new scope values explicitly.

### PostgreSQL

Advance the schema migration ledger to version 4 in one transaction:

- add `scope_id TEXT NOT NULL DEFAULT 'default'` to execution, journal and outbox tables;
- create composite indexes for the scoped query order;
- preserve the default for old application versions during rolling deployment;
- ensure new application writes always bind the validated scope explicitly.

Use a separate migration role in production. Do not perform schema DDL from a low-privilege application role.

## Query contract

Introduce a storage-neutral query model shared by journal, outbox and operator-action inspection:

- `scopeId` (required)
- `fromInclusive` and `toExclusive` (optional UTC instants)
- status/state filter (optional set)
- `pageSize` (default 50, hard maximum 200)
- `after` (optional typed cursor)
- `snapshotAt` (optional stable upper-bound instant for a multi-page traversal)

Each result contains immutable items, a next cursor when more rows exist, and the snapshot boundary. The cursor must include the last row's timestamp plus unique ID, query version, scope binding and filter fingerprint. Reject malformed cursors and cursors whose scope/filter fingerprint does not match the request.

Recommended total orders:

| Record family | Order | Unique tie-breaker |
|---|---|---|
| Journal | `updated_at DESC` | `idempotency_key DESC` |
| Outbox | `occurred_at DESC` | `event_id DESC` |
| Operator action | `occurred_at DESC` | `action_id DESC` |

The SQL predicate for descending keyset pagination is lexicographic: timestamp less than the cursor timestamp, or timestamp equal and unique ID less than the cursor ID. Use parameter binding; never interpolate scope or filter values into SQL.

## Snapshot semantics

A page sequence is not automatically a database-wide immutable snapshot. The first page should capture a `snapshotAt` upper bound and subsequent pages should constrain rows to that boundary. This prevents newer inserts from continually shifting the traversal. Updates to journal rows can still change their `updated_at`; if strict repeatable traversal is required, use a database snapshot/transaction or an append-only journal revision model. The API must state which guarantee the adapter provides.

For operational dashboards, bounded eventual consistency is acceptable. For audit exports, use a repeatable-read export transaction or a materialized export job rather than pretending ordinary keyset pagination is a serializable snapshot.

## Admin service integration

Keep the existing `PluginRevocationAdminOperationsService.inspect()` compatibility method for small datasets and legacy host resolvers. Add a paged method that:

1. validates scope and query bounds;
2. authorizes the principal for the requested scope;
3. appends the allowed/denied access audit record;
4. fails closed if audit persistence fails;
5. calls only the scoped query-store interfaces;
6. returns page metadata and scoped counts without reading unrelated scopes.

Do not call `readAll()` and filter in memory from the new paged method. If a configured adapter does not implement the scoped query capability, return an explicit unsupported-capability error rather than silently falling back to an unbounded scan.

## Retention and archival

Retention must be scope-aware and must not delete unresolved journal entries, pending/leased outbox rows, or dead-letter records still inside the configured audit retention period. Delivered outbox events may be archived only after a configurable minimum age and after downstream delivery evidence is retained. Journal history should be retained independently from outbox delivery state.

Implement retention as an explicit maintenance service with dry-run planning, bounded batches, an audit record, and a host-provided policy. Do not put automatic deletion into ordinary query methods or database startup migrations.

## Test matrix

The implementation PRs must cover:

- trusted scope carried from coordinator input to pending journal, terminal journal and outbox event;
- rejection of a terminal scope mismatch with full transaction rollback;
- legacy migration rows assigned only to the documented compatibility scope;
- cross-scope query isolation for every record family;
- same-timestamp records ordered deterministically by unique ID;
- page boundaries with no duplicates or omissions;
- invalid, tampered, expired and cross-scope cursors rejected;
- cursor/filter mismatch rejected;
- inclusive lower and exclusive upper time bounds;
- empty result and final page behavior;
- bounded page size enforcement;
- snapshot boundary behavior under concurrent inserts;
- SQLite migration from schema v3 and PostgreSQL migration from schema v3;
- PostgreSQL integration tests gated by `ALHAMBRA_TEST_DATABASE_URL`.

## Delivery sequence

1. Add scope context to coordinator and immutable records, preserving existing constructor compatibility.
2. Add SQLite/PostgreSQL schema v4 migrations and scope consistency checks in transactional writes.
3. Add scoped keyset query contracts and implement them in both durable adapters.
4. Add paged admin service method with authorization-before-query and access auditing.
5. Add retention planning as a separate, opt-in maintenance capability.
6. Add REST/gRPC/admin-console adapters outside the runtime package.

Each step should be independently reviewable, and the paged service must not ship before both durable adapters can enforce scope predicates in the database.

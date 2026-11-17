# Scoped Revocation Administrative Operations

## Purpose

Alhambra exposes a host-neutral administrative query service for inspecting revocation state within an authorized security scope. It is an application service, not an HTTP API. Hosts may adapt it to REST, gRPC, CLI, desktop UI or an internal support console.

## Runtime boundary

`PluginRevocationAdminOperationsService` composes the existing read-only `PluginRevocationOperationsService` with four host ports:

- `PluginRevocationOperationsAuthorizer` decides whether an authenticated principal may inspect a requested scope.
- `PluginRevocationOperationsScopeResolver` resolves journal and outbox record ownership from authoritative host metadata.
- `PluginRevocationOperatorActionInspectionStore` reads durable operator replay history.
- `PluginRevocationOperationsAccessAuditStore` records allowed and denied inspection attempts.

The principal contains only the authenticated actor ID. The host derives it from its verified identity context. The service does not parse JWTs, choose an identity provider, or trust a caller-supplied actor field in a request body.

## Request sequence

1. Validate the requested scope.
2. Ask the host authorizer to authorize the principal for that scope.
3. Append an access-decision audit record.
4. If denied, throw `PluginRevocationOperationsAccessDeniedException` without reading journal, outbox or operator history.
5. If allowed, read the operational projection and operator replay history.
6. Resolve journal and outbox ownership through the host resolver.
7. Return a snapshot containing only records matching the authorized scope, with counts recalculated from those filtered records.

If the access-audit sink fails, the service fails closed and does not return operational data. The in-memory audit sink is a test/reference implementation only; production hosts must provide a durable, access-controlled sink.

## Scope and data ownership

Operator replay actions carry a persisted `scopeId`, so they can be filtered directly. Existing journal and outbox schemas predate tenant-aware ownership. Until those records persist a scope field, the host resolver must use trusted metadata such as an authoritative operation-to-tenant mapping. It must not infer ownership from untrusted event payloads or plugin IDs supplied by a caller.

The current query service uses the portable `readAll` contracts and filters records in process. This is suitable for moderate datasets but loads all rows before filtering. Production deployments with large journals/outboxes should implement a database-side scoped, cursor-paginated query contract before exposing the service to broad operator audiences. Do not treat in-memory filtering as a substitute for database row-level security.

## Audit semantics

Every authorization decision is appended before data is returned or denied. The audit record includes actor, requested scope, decision, a stable denial code when denied, and occurrence time. Do not store access tokens, raw credentials, or sensitive request payloads in this record.

Denied attempts must be retained by the host according to its security and compliance policy. Rate limiting and alerting for repeated denied attempts also belong to the host.

## Adapter conformance

SQLite and PostgreSQL implement `PluginRevocationOperatorActionInspectionStore`. Both must return the persisted scope value from the operator-action table. SQLite schema v3 adds `scope_id` transactionally; PostgreSQL migration v3 adds the same field. Historical rows are assigned `default` as a compatibility value only.

## Non-goals

- No HTTP route, RPC server, CLI, or UI.
- No built-in Keycloak, OPA, OAuth, or tenant directory integration.
- No direct mutation of journal/outbox state.
- No claim, acknowledge, reschedule, retry, replay or reconciliation operation through this query service.
- No claim of serializable cross-table snapshot consistency.


## Persisted scope ownership

New durable adapters persist the trusted scope assigned at execution time on execution, journal and outbox rows. The admin inspection service filters directly on those immutable fields; it no longer needs to infer ownership from plugin or provider identifiers. The legacy scope-resolver hook remains optional for source compatibility but is deprecated. Rows created before schema v4 are assigned the explicit compatibility scope `default` and should be migrated or mapped by the host before exposing them in a multi-scope deployment.


## Authorized paginated inspection

PluginRevocationAdminPageService exposes three database-native page operations:

- journalPage: journal entries, with optional status and time filters.
- outboxPage: outbox messages, with optional state and time filters.
- operatorActionPage: durable operator replay actions, with time filters.

Each request carries a validated scoped query object. The service uses that query's scopeId as the authorization boundary; callers cannot supply a separate scope that differs from the query. The service sequence is:

1. Validate the query's scope and page bounds (in the query constructor).
2. Ask the host authorizer to authorize the authenticated principal for that scope.
3. Append an access audit containing the resource family, page size, whether a continuation was supplied, and a SHA-256 fingerprint of the normalized query filters. The raw cursor is never written to the audit.
4. Stop on denial, or on access-audit persistence failure.
5. Require PluginRevocationScopedQueryStore and execute the matching database-native page query.
6. Return the adapter page and opaque continuation unchanged.

The access audit is written before the data query. A failed audit append prevents the query. Denied access is audited before the denial exception is raised. A missing scoped-query adapter is also fail-closed; this service never falls back to readAll and in-memory filtering.

The host must configure the same durable access-audit sink and a scoped-query adapter backed by the appropriate database package. The older PluginRevocationAdminOperationsService.inspect() remains available for compatibility and operational snapshots, but it is not a substitute for the paginated service on large datasets.

### Cursor and consistency rules

Continuation tokens are opaque and must be passed back unchanged with the same scope, resource family, normalized filters, time range and page size. Durable adapters authenticate the cursor and reject cross-scope or cross-query reuse. The runtime audit records only a fingerprint and a boolean indicating whether a cursor was supplied.

The adapter's snapshotAt value is an ordering-timestamp ceiling, not a strict insertion snapshot. Backdated late arrivals and mutable journal ordering fields can affect traversal. Do not use ordinary page traversal as a compliance-grade immutable export; use a transactionally consistent database snapshot or a dedicated export job for that requirement.

### Host integration checklist

- Derive PluginRevocationOperationsPrincipal.actorId from verified host identity, never from an untrusted request field.
- Implement PluginRevocationOperationsAuthorizer against the host's policy engine.
- Persist PluginRevocationOperationsAccessAudit records in a durable, access-controlled sink.
- Supply PluginRevocationScopedQueryStore from the SQLite or PostgreSQL package, configured with a stable cursor signing secret of at least 32 bytes.
- Keep cursor secrets shared across service instances and stable across restarts; rotate them deliberately because rotation invalidates outstanding cursors.
- Translate access-denied, invalid-cursor and unavailable-query-capability exceptions at the host API boundary without leaking database details.

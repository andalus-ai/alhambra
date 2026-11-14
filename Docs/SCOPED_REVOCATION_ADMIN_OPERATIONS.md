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

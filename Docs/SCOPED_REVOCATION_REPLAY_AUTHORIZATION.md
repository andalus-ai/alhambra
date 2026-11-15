# Scoped Revocation Replay Authorization

## Purpose

Dead-letter replay is an operator action, not a normal retry. The runtime provides a host-neutral command service that enforces a consistent authorization sequence before invoking the durable replay store.

The command service does not parse JWTs, authenticate users, query Keycloak, call OPA, or interpret a change-management system. Those integrations are supplied by the embedding host.

## Authorization sequence

1. The host constructs `PluginRevocationReplayPrincipal` from its authenticated identity context. The caller cannot supply an arbitrary actor ID separately from this principal.
2. `PluginRevocationReplayScopeResolver` resolves the target event's authoritative scope.
3. The service requires the resolved scope to equal the principal's scope.
4. `PluginRevocationReplayAuthorizer` verifies that the principal may replay the target event (for example, permission `plugin.revocation.replay`).
5. `PluginRevocationReplayApprovalVerifier` verifies the approval/change reference for this actor, target and scope.
6. Only then does the service invoke `PluginRevocationDeadLetterReplayStore`.

Any failed gate raises `PluginRevocationReplayDeniedException` and the persistence store is not called.

## Scope semantics

`scopeId` is an opaque host-defined security boundary. It may represent a tenant, workspace, environment, or another partition. Alhambra does not prescribe an identity provider or tenant model.

The host scope resolver must use authoritative resource ownership data. It must not trust a scope ID submitted by a client or infer ownership from a plugin ID. The resolved scope is recorded with the operator audit action. Existing audit rows are migrated with scope `default`; this is a compatibility value, not proof that the old row belongs to a particular tenant.

## Host integration

A production host should:
- derive actor and scope from a verified identity/session;
- use deny-by-default authorization;
- scope the event lookup to the authenticated tenant/workspace;
- verify approval references against a durable approval system;
- rate-limit and separately audit denied attempts;
- expose replay only through an authenticated administrative surface;
- keep approval IDs and reasons sanitized and non-secret.

The command service rechecks authorization on every invocation, including idempotent retries. This prevents an old action ID from bypassing a newly revoked permission.

## Persistence and delivery

SQLite and PostgreSQL adapters persist the scope alongside actor, reason, approval reference, source event, replay event and generation in the same transaction as the new replay outbox row.

The original dead-letter row is never reset. A replay gets a new event ID and idempotency key and is delivered through the normal at-least-once outbox dispatcher. Consumers must deduplicate by event ID.

## Explicit non-goals

- No built-in HTTP endpoint or admin UI.
- No built-in Keycloak/OPA client.
- No automatic approval creation.
- No replay of arbitrary pending, leased or delivered events.
- No exactly-once external side effects.

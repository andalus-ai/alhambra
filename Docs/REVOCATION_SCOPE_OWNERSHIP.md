# Revocation Scope Ownership

## Purpose

Schema v4 adds persisted scope ownership to revocation execution, journal and outbox records. Scope is an ownership boundary assigned by the embedding host; it is not inferred by Alhambra from plugin identifiers or caller-controlled resource fields.

## Assigning scope

Resolve scope from authenticated host context and pass it to the coordinator:

```dart
final report = await coordinator.execute(
  operationId: providerEvent.id,
  decisions: decisions,
  scopeId: authenticatedTenantId,
);
```

The coordinator trims and validates the scope before accepting work. The default `default` value remains for single-scope and source-compatible deployments. Multi-tenant hosts should always pass the authenticated tenant/organization scope explicitly.

Do not pass a scope read directly from an untrusted request body. The host must authorize the operation before calling the coordinator.

## Propagation and immutability

The same scope is carried through:

1. pending execution/idempotency record;
2. initial journal row;
3. terminal execution update;
4. journal status/revision update;
5. terminal audit outbox event;
6. dead-letter replay event (inherited from the source event).

A terminal write with a different scope fails and rolls back the transaction. Journal compare-and-set cannot change scope. A replay request must match the source dead-letter event's scope; a replay cannot move an event between tenants.

The idempotency key remains based on operation/plugin/provider/action. Reusing the same key under a different scope is rejected rather than creating a second execution lineage.

## Schema migration

SQLite schema v4 adds `scope_id` to execution, journal and outbox tables and creates scope-first ordering indexes. Existing rows receive the compatibility value `default`.

PostgreSQL schema v4 is available at `packages/alhambra_plugin_revocation_postgres/migrations/004_scope_ownership.sql` and is also applied by `PostgresPluginRevocationStore.migrate()`. It adds the same fields and indexes transactionally.

Deployments upgrading from earlier schemas must treat existing rows as belonging to `default`. Do not reinterpret those records as belonging to a tenant based on plugin ID. If legacy records need reassignment, perform a separately reviewed migration using authoritative ownership data before enabling tenant-scoped inspection.

## Administrative inspection

`PluginRevocationAdminOperationsService` filters journal rows by `entry.scopeId`, outbox rows by `message.event.scopeId`, and replay operator actions by their persisted `scopeId`. Authorization and durable access auditing still occur before operational reads.

The old host scope resolver remains only as a deprecated source-compatibility hook; it is no longer authoritative when records carry persisted scope.

## Limitations

This increment establishes scope ownership and migration safety. It does not yet implement database-native scoped pagination. The compatibility `inspect()` path still reads all rows before filtering. The next increment must add bounded database queries with scope predicates applied before LIMIT, deterministic keyset cursors and explicit snapshot semantics.

# Durable Plugin Revocation Journal and Recovery

## Scope

This phase adds a persistence-neutral journal contract and a read-only recovery
planner for governed provider-impact operations. It complements the existing
plugin lifecycle checkpoint/recovery system; it does not replace it.

## Journal record

Each entry is schema-versioned and carries:
- idempotency key, operation ID, and correlation ID;
- plugin ID, provider owner ID, and impact action;
- status, approval outcome, timestamps, and sanitized detail;
- monotonically increasing record revision.

The store contract requires atomic `createIfAbsent` and revision-based
`compareAndSet`. `JournalBackedPluginRevocationExecutionStore` adapts this
journal to the existing `PluginRevocationCoordinator` execution-store contract
and accepts a host correlation-ID resolver. A database adapter should implement
these operations with a unique constraint/conditional insert and a transaction
or conditional update that checks the expected revision. The in-memory adapter
is for tests only.

## Recovery classifications

The planner compares journal entries with the authoritative active plugin set
reported by `PluginManager` while holding its lifecycle batch gate.

- pending/failed deactivation + plugin active: ambiguous; inspect partial
  teardown and do not call deactivate automatically;
- pending/failed deactivation + plugin inactive: verify plugin-owned external
  resources before resolving;
- pending/failed non-deactivation action: inspect the authoritative subsystem;
- completed deactivation + plugin active: investigate stale journal state,
  later activation, or ownership/concurrency violations.

The planner is read-only. It does not retry, approve, compensate, or mutate
journal entries.

## Explicit resolution

`PluginRevocationJournalResolver` records a host-verified resolution with
revision CAS. It only resolves pending/failed records; it never executes plugin
code. A new execution attempt must use a new operation ID and a fresh approval
decision. A stale operator/job cannot overwrite a newer record because its
expected revision will fail.

## Production requirements and limitations

- Persist journal records in a transactional database or durable log.
- Enforce idempotency-key uniqueness across all runtime instances.
- Implement CAS atomically and define transaction isolation.
- Retain correlation IDs across provider event, impact decision, lifecycle
  operation, and audit event.
- Keep audit append durability aligned with journal completion; a production
  adapter should use a transactional outbox or equivalent.
- Store only sanitized error classifications; never credentials, arbitrary
  exception text, or provider payloads.

This phase intentionally does not claim a concrete SQL/SQLite/PostgreSQL
adapter, distributed lease, automatic retry worker, or exactly-once side effect
execution. Those depend on the host's chosen persistence and transaction
infrastructure.

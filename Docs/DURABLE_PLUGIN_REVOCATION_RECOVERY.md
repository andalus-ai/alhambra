# Durable Plugin Revocation Journal and Recovery

## Scope
This phase adds persistence-neutral contracts for a versioned revocation journal
and host-driven reconciler. It does not ship a database adapter. The in-memory
store is only a reference implementation for tests and single-process use.

## Journal invariants
- Persist identity, operation/plugin/provider IDs, action, status, correlation ID,
  schema version, UTC timestamps, and monotonically increasing revision.
- Persist enum names, not enum ordinals.
- Production adapters must implement linearizable insert-if-absent and
  compare-and-set across every host process.
- Never overwrite a newer revision with a stale recovery worker.

## Recovery protocol
1. Load pending, failed, retry-authorized, and manual-review entries.
2. Inspect authoritative host lifecycle state; do not infer from journal status
   or a health projection alone.
3. If already applied, mark reconciled without replay.
4. If unknown, retain manual review.
5. If not applied, require explicit host retry approval.
6. Persist retry authorization before invoking the retry executor.
7. If retry throws or completion cannot be persisted, inspect again; do not
   assume an exception means the side effect did not happen.

The retry callback must preserve the original idempotency key. The reconciler
does not schedule itself; hosts choose startup, periodic, or operator-triggered
execution.

## Production requirements and boundaries
No SQL/KV adapter, transaction implementation, backup/restore, retention, or
migration tooling is included. The journal never serializes plugin instances,
runtime contexts, credentials, provider payloads, or arbitrary plugin state.
Correlation IDs allow host audit systems to join provider, operation, and
plugin lifecycle events. Keep secrets and untrusted exception text out of
journal details.

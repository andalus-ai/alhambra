# Transactional Revocation Audit Outbox

## Problem

The legacy coordinator writes the terminal execution record and then appends an
audit record through two independent calls. A crash between them can leave a
completed revocation without an audit event; reversing the order can produce
an audit event for an outcome that was not durably committed.

## Atomic outcome boundary

`TransactionalPluginRevocationStore` combines the execution store and audit
sink contracts and adds `completeAndEnqueue`. The coordinator uses this path
when the same object is supplied for both dependencies. A production adapter
must commit the terminal execution update and a uniquely identified outbox
event in one database transaction.

The old two-call path remains for backwards compatibility. It is explicitly
non-atomic and should not be used for production revocation governance.

## Outbox model

Each audit event contains sanitized identifiers and outcome metadata:
operation ID, idempotency key, plugin ID, provider owner ID, action, outcome,
timestamp, and optional sanitized detail. It must not contain credentials,
plugin payloads, arbitrary exception messages, or secrets.

Messages transition through:
- pending: eligible for delivery at/after `nextAttemptAt`;
- leased: claimed by one worker until `leaseUntil`;
- delivered: publisher accepted the event;
- deadLetter: maximum attempts exhausted; host intervention is required.

Claims are ordered by event time. Expired leases can be reclaimed. Every
acknowledgement/reschedule operation must match the current lease token, so a
stale worker cannot acknowledge a message reclaimed by another worker.

## Delivery guarantees

Delivery is **at least once**, not exactly once. A publisher may successfully
send an event and the worker may crash before acknowledging it. The event can
then be delivered again after lease expiry. Consumers must deduplicate using
the stable `eventId`.

The dispatcher applies bounded exponential backoff and moves exhausted events
to dead letter. A host should alert on dead-letter growth and provide an
operator replay workflow with its own audit trail.

## Production adapter contract

A SQL-backed adapter should:
1. update the execution journal and insert the outbox row in one transaction;
2. enforce unique constraints on idempotency key and event ID;
3. claim rows using a transaction-safe lease mechanism (for example,
   `SELECT ... FOR UPDATE SKIP LOCKED`, or an equivalent atomic update);
4. update delivery state only when the lease token still matches;
5. persist attempts, lease expiry, next attempt time, and sanitized error code;
6. retain delivered/dead-letter records according to host retention policy.

The in-memory implementation is a single-isolate reference for tests. It is not
crash durable, cross-process safe, or a substitute for a database adapter.

## Compatibility

Existing `PluginRevocationExecutionStore` and `PluginRevocationAuditSink`
implementations continue to work through the legacy two-call path. Hosts obtain
the atomic guarantee only when the same implementation implements
`TransactionalPluginRevocationStore` and is passed as both dependencies.

# Revocation Operations and Inspection

## Purpose

The runtime exposes a storage-neutral, read-only operational projection over the durable revocation journal and audit outbox. Hosts can use it to build admin screens, health endpoints, support tooling and alerting without coupling those surfaces to SQLite or PostgreSQL.

## Runtime contract

- `PluginRevocationOutboxInspectionStore` is a separate read-only capability; it does not extend the claim/acknowledge contract.
- `PluginRevocationOperationsService.inspect()` reads journal entries and outbox messages and returns an immutable `PluginRevocationOperationsSnapshot`.
- The snapshot includes counts by journal/outbox state, unresolved journal count, due pending messages, expired leases, and the underlying immutable records for host-side filtering.
- The in-memory implementation is a test/reference adapter. Production hosts should use a durable adapter.

## Metrics and operator views

Expose at least:

| Signal | Meaning |
|---|---|
| Journal count by status | Pending, completed, rejected, failed, retry-authorized, manual-review and reconciled states |
| Unresolved journal entries | Entries whose status still requires reconciliation |
| Outbox count by state | Pending, leased, delivered and dead-letter messages |
| Overdue pending messages | Pending messages whose `nextAttemptAt` is due at snapshot time |
| Expired leases | Leased messages whose lease deadline has passed |
| Attempts and last error code | Delivery retry diagnostics for each outbox message |

Hosts should derive oldest-pending age, delivery latency, retry rate and dead-letter rate from timestamps and counters. Avoid using plugin IDs, operation IDs or event IDs as metric labels; keep high-cardinality identifiers in access-controlled logs and detail views.

## Consistency and pagination

The current portable service performs two independent reads: journal `readAll()` and outbox `readAllOutbox()`. Concurrent writes may occur between them. Treat the result as an operational projection, not a serializable cross-table transaction snapshot. PostgreSQL/SQLite adapters currently return all rows; large installations should add cursor-based paging and bounded retention/archival before using this API for unbounded datasets.

## Security

These records may contain plugin identifiers, provider ownership, correlation IDs and sanitized operational details. Admin endpoints must require host authorization, enforce tenant/organization scope where applicable, redact detail fields by default, and audit access according to the host's security policy. The runtime does not expose an HTTP endpoint or assume an identity provider.

## Mutation policy

Inspection never claims an outbox message, changes a lease, or resolves a journal entry. Existing journal reconciliation primitives remain explicit host workflows:

- `PluginRevocationRecoveryPlanner` classifies interrupted actions against authoritative runtime state; it never invokes plugin code.
- `PluginRevocationJournalResolver` records a host-verified resolution using revision compare-and-set; it does not replay an action.
- `PluginRevocationReconciler` supports an explicitly approved retry callback only after authoritative inspection confirms the action was not applied. Hosts must place an operator identity, approval evidence and durable audit record around that workflow.

Dead-letter replay is deliberately not part of this read-only phase. A safe replay API must atomically record operator authorization, increment a replay generation or create a new event identity, and transition the dead-letter row. Reusing a delivered event ID or simply changing `deadLetter` to `pending` could duplicate external effects. Implement that only with a transactional operator-audit store contract.

## Example

```dart
final operations = PluginRevocationOperationsService(
  journalStore: persistence.journalStore,
  outboxStore: persistence,
);

final snapshot = await operations.inspect();
print('Unresolved: ${snapshot.unresolvedJournalEntries}');
print('Dead-letter: ${snapshot.deadLetterOutboxMessages}');
print('Expired leases: ${snapshot.expiredLeases}');
```

## Validation boundary

Unit tests cover state aggregation, immutable results, overdue work, expired leases and the fact that inspection does not mutate outbox state. Adapter tests verify direct read-only inspection. A full production validation still requires Dart formatting/analyzer and SQLite/PostgreSQL integration test execution.


## Audited dead-letter replay contract

The runtime now defines `PluginRevocationDeadLetterReplayStore`, an explicit command and an immutable operator-action audit record. A replay request must carry a host-authenticated actor identifier, a non-empty reason, an approval/change reference, a stable action ID and the target event ID. The runtime does not authenticate the actor or decide whether the referenced approval is valid; the host must perform those checks before calling the store.

A conforming durable adapter must atomically:

1. Verify that the target event currently is `deadLetter`.
2. Return the prior result when the same action ID is repeated with identical request details; reject reuse of an action ID for different details.
3. Allocate the next replay generation for the source event.
4. Insert an operator-action audit record.
5. Insert a new pending outbox message with a new event ID and idempotency key, linked to the source event and replay generation.
6. Commit the audit and new outbox row together.

The original dead-letter row is never reset or overwritten. A replay is a new delivery attempt lineage and remains at-least-once; downstream consumers must deduplicate by the new event ID while retaining the source-event link for audit correlation.

The in-memory reference implementation demonstrates these semantics within one Dart isolate only. It is not durable, cross-process safe, or suitable for production. SQLite and PostgreSQL durable implementations of this new contract are a separate adapter-conformance step; do not treat the interface alone as a production replay facility.

Hosts must authorize operators, validate approval evidence, scope access to the correct tenant/organization, and protect actor/reason/ticket data. Do not accept actor identity from an untrusted request body.

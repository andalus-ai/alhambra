# Alhambra Plugin API

Framework-neutral contracts shared by Alhambra hosts, plugins, and runtime
implementations. The API package contains contribution models, composition
contracts, lifecycle events, and storage/observability ports. It has no
dependency on a concrete persistence engine or product UI.

## Composition lifecycle observability

The composition API defines:

- `CompositionLifecycleEvent`: immutable correlation, operation, outcome,
  timestamp, node/owner IDs, duration, and safe error-summary fields.
- `CompositionLifecycleEventStore`: asynchronous persistence/query port.
- `CompositionLifecycleObservability`: subscription, bounded-history query,
  correlation timeline, and owner-summary contract.
- `CompositionLifecycleEventSubscription`: cancellation and per-subscriber
  dropped-event reporting.

Hosts may implement these contracts with in-memory, JSONL, database, or remote
telemetry adapters. Runtime implementations should isolate observer failures
from composition correctness and make event loss/backpressure observable.


## Lifecycle storage health

`CompositionLifecycleStorageHealthProvider` is an optional capability for adapters that can report storage health. Its immutable snapshot distinguishes healthy, degraded, unavailable, and unknown states. Unsupported measurements remain null rather than being reported as zero. The common model can carry write-queue counts, record count, primary/auxiliary byte footprints, last successful write time, and backend-specific metrics without requiring every `CompositionLifecycleEventStore` implementation to support them.

## Lifecycle storage maintenance

`CompositionLifecycleStorageMaintenanceProvider` is an optional capability for explicit retention and maintenance operations. Hosts provide a request with an inclusive retention timestamp, a maximum retained event count, and/or a checkpoint request. Maintenance is never scheduled implicitly. Results report records removed, checkpoint outcome when supported, warnings for unsupported or incomplete work, and backend-specific metrics. A partial result does not mean the requested operation was rolled back; inspect the reported actions and warnings.


## Lifecycle maintenance policy planning

`CompositionLifecycleStorageMaintenancePlanner` evaluates a declarative policy
against a health snapshot and host-supplied maintenance history. It returns
trigger reasons, unavailable metrics, minimum-interval gating, and an optional
explicit maintenance request. The planner is deterministic and performs no
I/O, scheduling, authorization, or execution.

A retention age produces a periodic inclusive cutoff because the common health
contract does not require adapters to report the oldest event timestamp. Event
count and storage-footprint thresholds are evaluated only when their required
measurements are available. The combined storage threshold requires both
primary and auxiliary byte counts; unknown values are never treated as zero.
A storage threshold is a trigger for review/maintenance, not a guarantee that
a particular action will reclaim the reported amount of space.

Hosts remain responsible for scheduling evaluations, persisting maintenance
history, enforcing authorization, serializing operations, and executing the
returned request through an adapter's optional maintenance capability.

## Lifecycle maintenance coordination

`CompositionLifecycleStorageMaintenanceCoordinator` is an explicit
single-flight execution primitive for a host-defined store scope. A host
supplies an operation ID, maintenance request, and executor callback. A second
operation submitted through the same coordinator while one is active is
rejected with `StateError`; this is an in-process, per-instance guard, not a
cross-process lock.

An optional `CompositionLifecycleStorageMaintenanceAuditLog` receives a
started record before execution and a terminal record afterwards. Failure to
persist the started record fails closed and prevents execution. Failure to
persist the terminal record is exposed separately on the operation outcome so
it cannot silently erase the execution result. Hosts should provide a durable
audit implementation when durable history is required.

Cancellation before the executor starts prevents execution. During execution,
cancellation is cooperative: the executor receives a signal and must check it
at safe boundaries. The coordinator does not interrupt an in-flight Future or
claim that already-applied destructive work was rolled back. Executors should
return a partial result with a warning when they stop after work has begun.

The coordinator does not schedule operations, choose policy, inspect storage,
or perform authorization. Hosts own those responsibilities and must provide
stronger external locking when multiple coordinator instances or processes
can target the same store.


## Lifecycle maintenance audit history and recovery

Hosts that need durable, queryable history can implement the optional
`CompositionLifecycleStorageMaintenanceAuditStore`. It extends the
coordinator's append-only audit sink with bounded queries by operation ID,
status, inclusive time range, and an exclusive keyset cursor. Results are
ordered oldest-first by `(startedAt, operationId, status.name)`. Implementors
should make appends idempotent for an identical `(operationId, status)`
record and reject conflicting reuse with `CompositionLifecycleStorageMaintenanceAuditIdentityConflictException`.

`CompositionLifecycleStorageMaintenanceRecovery.classify` interprets the
records for one operation without performing recovery or replay. A start
record without a terminal record is `outcomeUnknown`: the process may have
stopped after destructive work was applied but before the terminal audit write.
A terminal record without a start record is incomplete history. Duplicate or
inconsistent records are conflicting history. Only a matching start and one
terminal record establish a known terminal status.

Audit history alone never authorizes automatic retry, including after a
recorded failure. Hosts must reconcile unknown outcomes and require an
executor/adapter-specific idempotency or reconciliation guarantee before
replaying maintenance. The API does not claim exactly-once execution or a
transaction spanning the maintenance backend and audit store.


The versioned `CompositionLifecycleStorageMaintenanceAuditJsonCodec` is shared
by the file and SQLite adapters. Maintenance audit metrics must contain
JSON-compatible values; unsupported values fail encoding rather than being
silently stringified. Concrete adapters are optional and host-owned.

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

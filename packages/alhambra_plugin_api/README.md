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

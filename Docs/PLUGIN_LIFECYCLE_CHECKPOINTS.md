# Plugin Lifecycle Checkpoints

## Purpose

The plugin runtime exposes a persistence-neutral checkpoint contract so an
application host can record lifecycle progress in its own durable store. The
runtime package does not select a database, filesystem format, serialization
library, or cloud provider.

## Record contents

A checkpoint contains a schema version, plugin ID, lifecycle operation ID,
startup/shutdown operation, last observed state, per-plugin sequence and
attempt, timestamps, dependency IDs, and optional sanitized failure metadata.
It excludes plugin instances, runtime contexts, configuration secrets,
credentials, and arbitrary plugin-owned state.

## Coordinator integration

Both startup and shutdown coordinators accept an optional
PluginLifecycleCheckpointStore and optional operation-ID factory. When a
store is configured, coordinators:

1. Persist the complete planned set before invoking plugin lifecycle hooks.
2. Persist starting or stopping immediately before each side effect.
3. Persist active or stopped after successful completion.
4. Persist failed for failed lifecycle operations.
5. Persist rollbackPending, then stopped or rollbackFailed, during startup
   compensation.

A failure to persist the planned set prevents the batch from starting. A
failure to persist an individual pre-operation state prevents that plugin's
side effect. Startup compensation is still attempted if writing
rollbackPending fails: checkpoint storage must not prevent best-effort
cleanup of already-started plugins.

If a post-operation checkpoint write fails, the coordinator reports a failure
even though the plugin hook may already have completed. In particular, a
shutdown hook may have completed and PluginManager may have removed the plugin
from its active set even when the final stopped checkpoint could not be
written. Hosts should reconcile the checkpoint against live manager state.

## Recovery semantics

The starting, stopping, and rollbackPending states are ambiguous after a
process interruption. The host must inspect actual plugin and external resource
state before deciding whether to resume, compensate, or mark the operation
failed. A checkpoint is not proof that a side effect completed.

The contract does not provide exactly-once execution, distributed locking,
cross-process compare-and-set, plugin reconstruction, or automatic retry.
Plugins remain responsible for idempotency and compensation. Hosts must
document their store's durability and concurrency guarantees. Inject a
globally unique operation-ID factory when multiple processes can coordinate
lifecycle work.

## Recovery planner

`PluginLifecycleRecoveryPlanner` performs a read-only scan of all stored
checkpoints against the active plugin IDs reported by `PluginManager`. It
runs under the manager's lifecycle batch gate and returns sorted findings with
a disposition and host-facing guidance.

The planner distinguishes at least these cases:

- `planned` with an inactive plugin: not started; revalidate before a new run.
- `starting` with an active plugin: activation likely completed but the final
  checkpoint is stale; verify runtime and external side effects.
- `starting` with an inactive plugin: ambiguous; inspect side effects before
  retrying or compensating.
- `stopping` with an inactive plugin: shutdown likely completed; verify
  external cleanup before finalizing the checkpoint.
- `stopping` with an active plugin: partial teardown may have occurred;
  inspect before retrying.
- `rollbackPending`: determine whether compensation remains necessary.
- Active plugins with no checkpoint: establish provenance and a host-approved
  baseline.

The planner does not mutate the manager, health registry, or checkpoint store.
It does not reconstruct plugin instances, call lifecycle hooks, rewrite
checkpoints, or choose a retry policy. The host remains responsible for
external-resource inspection, idempotency decisions, checkpoint writes using a
new operation ID, and any explicit resume/compensation action.

## Store implementations

PluginLifecycleCheckpointStore is the host persistence boundary.
InMemoryPluginLifecycleCheckpointStore is for tests and ephemeral hosts only;
it does not survive process restart. Persistent adapters should atomically
replace a plugin's checkpoint and preserve schema versions.

## Scope

This integration records lifecycle progress and provides a read-only recovery
planner. It does not execute recovery actions, reconstruct plugin instances,
or guarantee distributed exactly-once behavior. Those remain host-level
responsibilities.

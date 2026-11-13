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


## Explicit recovery actions

`PluginLifecycleRecoveryController` applies a narrow set of host-approved
checkpoint decisions:

- `acknowledgeActive`: only when `PluginManager` confirms the plugin is active.
- `acknowledgeStopped`: only when `PluginManager` confirms the plugin is inactive.
  The host must separately verify external cleanup before using this action.
- `markFailed`: only when the plugin is inactive and the host supplies a
  non-empty failure summary.

Every action requires the operation ID and sequence observed by the caller and
a new operation ID for the recovery decision. The controller rejects stale
requests and writes the next sequence while holding the manager's lifecycle
batch gate. It preserves dependency metadata and clears obsolete failure
metadata when acknowledging a successful state.

These checks protect against stale callers within one manager instance. The
current store contract does not provide cross-process compare-and-set: hosts
that allow multiple processes to update the same plugin checkpoint must
serialize writes externally or extend their persistence adapter with an
atomic conditional-write guarantee. The controller never invokes
`activate()`, `deactivate()`, or plugin-specific compensation.



## Controlled recovery execution

`PluginLifecycleRecoveryRunner` is the explicit execution boundary for
recovering one plugin at a time. A host supplies a
`PluginLifecycleRecoveryExecutor` implementation. The runner provides a
context containing the compiled plugin and inspected checkpoint; the executor
performs plugin-specific idempotency checks and external preparation, then
must invoke exactly one matching lifecycle operation through the context.

Supported actions:

- `resumeStartup`: accepts an incomplete startup checkpoint, requires a
  matching compiled plugin instance and all declared dependencies to be
  active, then calls the normal `PluginManager.activate()` path.
- `compensateShutdown`: accepts an interrupted shutdown or pending startup
  rollback, requires the target to be active, and refuses to stop it while an
  active dependent remains. It calls the normal `PluginManager.deactivate()`
  path.

Each execution requires the operation ID and sequence previously inspected by
the host plus a new operation ID. The runner writes an in-flight checkpoint
before invoking host code, increments the attempt, and records active/stopped
on success or failed on an execution error. If the final checkpoint write
fails after the plugin action completed, the in-flight record remains a signal
for the recovery planner and the host must reconcile against live manager
state.

The runner handles one plugin per call. Hosts must order startup calls
dependency-first and shutdown/compensation calls in reverse dependency order.
The host executor must be idempotency-aware: a failed attempt may have
performed partial external work, and the runner does not promise exactly-once
execution. The manager-wide lifecycle gate protects one manager instance;
multiple host processes still require external serialization or a store with
atomic conditional writes.

The executor must call the matching context method exactly once. It may
perform external checks or compensation around that call, but it must not
retain secrets in checkpoint failure summaries or exception messages.


## Dependency-ordered recovery batches

`PluginLifecycleRecoveryRunner.executeBatch()` coordinates an explicit set of
recovery targets under one manager-wide lifecycle batch gate. It reads the
checkpoint set, validates target states and dependency prerequisites, computes
a stable topological order, and then invokes the existing single-plugin
recovery path sequentially.

- Startup recovery executes dependency-first. Dependencies outside the selected
  batch must already be active.
- Shutdown compensation executes dependent-first. Active dependents outside
  the selected batch block compensation.
- A dependency cycle or invalid/missing prerequisite fails preflight before
  plugin code runs.
- Each target receives a distinct operation ID supplied by the host factory.
  IDs are generated and validated before the first lifecycle operation.
- The batch stops at the first execution failure. The report identifies the
  failed plugin, completed plugins, and untouched remaining plugins. Successful
  checkpoints are retained; the host must inspect the failure before starting
  another batch.

The batch is not a distributed transaction and does not automatically retry.
The shared manager gate protects one `PluginManager` instance. Multi-process
hosts still need external serialization and checkpoint-store conditional
writes. Hosts should persist the batch intent in their own durable job/audit
store if they need to reconstruct the complete batch request after a process
restart; per-plugin checkpoints remain the source of execution progress.

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

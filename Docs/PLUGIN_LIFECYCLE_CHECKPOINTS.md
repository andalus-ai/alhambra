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

## Recovery semantics

The starting, stopping, and rollbackPending states are ambiguous after a
process interruption. The host must inspect actual plugin and external resource
state before deciding whether to resume, compensate, or mark the operation
failed. A checkpoint is not proof that a side effect completed.

The contract does not provide exactly-once execution, distributed locking,
cross-process compare-and-set, plugin reconstruction, or automatic retry.
Plugins remain responsible for idempotency and compensation. Hosts must
document their store's durability and concurrency guarantees.

## Store implementations

PluginLifecycleCheckpointStore is the host persistence boundary.
InMemoryPluginLifecycleCheckpointStore is for tests and ephemeral hosts only;
it does not survive process restart. Persistent adapters should atomically
replace a plugin's checkpoint and preserve schema versions.

## Delivery scope

This change establishes the record model and storage contract. Coordinator
checkpoint writes, interrupted-operation scanning, and host recovery policies
are subsequent integration work. Existing startup/shutdown behavior remains
unchanged until those integrations are added.

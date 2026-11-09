# Composition Persistence and Recovery

Alhambra composition snapshots are versioned, declarative descriptions of the
composition graph. They persist stable node identity, owner, phase, dependency
edges, and built-in node-specific identifiers. They do not persist runtime
instances, callbacks, service objects, closures, plugin binaries, or secrets.

## Runtime API

- `CompositionSnapshotCodec` encodes and validates the supported built-in
  composition node types.
- `CompositionSnapshotStore` is the storage port. Hosts can implement it with
  preferences, SQLite, files, or a remote database.
- `InMemoryCompositionSnapshotStore` is a lightweight reference implementation
  for tests and ephemeral runtimes.
- `CompositionPersistence.save` writes the next monotonically increasing
  generation; `restore` reconstructs a graph and validates it before exposing
  a `CompositionPlan`.
- JSON helper functions are provided for adapters that store a JSON document.

## Recovery boundary

Restoring a plan does not execute plugin code or recreate runtime resources.
The host must first rediscover and verify installed plugins, resolve their
contribution declarations, then pass the restored plan to the lifecycle
coordinator or reconciler. This keeps persistence independent of plugin
loading, UI frameworks, and application-specific startup policy.

## Storage guarantees

A store implementation must replace a snapshot atomically. A failed write must
leave the previously committed snapshot readable. Multi-process hosts should
add compare-and-swap or transactional generation checks in their adapter;
the base interface intentionally does not assume a database or locking model.

## Schema evolution

The current schema is version 1. Unknown schema versions fail closed rather
than silently dropping fields. Future schema changes should add explicit
migration steps and tests before changing the current schema version.

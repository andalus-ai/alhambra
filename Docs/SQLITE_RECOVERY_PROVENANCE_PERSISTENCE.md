# SQLite Recovery Provenance Persistence

The optional `alhambra_plugin_provenance_sqlite` package implements the
runtime's recovery provenance, signed-anchor, and signing-key history store
contracts without adding SQLite to `alhambra_plugin_runtime`.

## Storage layout

A `SqlitePluginRecoveryProvenancePersistence` instance owns one SQLite
connection and exposes three views:

- `provenanceStore`: one ordered provenance event chain per database;
- `anchorStore`: append-only anchors partitioned by `chainId`;
- `keyHistoryStore`: one ordered signing-key lifecycle history per database.

The provenance contract is chain-local and does not carry a chain ID on
append/read operations, so the adapter deliberately uses one database file per
provenance chain. Anchor records include their chain ID and can share that
database. Key history is shared by the database; hosts with separate key
administrative domains should use separate database files or a host-owned
partitioning adapter.

## Atomic append semantics

Each append runs under `BEGIN IMMEDIATE`. The adapter reads the current
sequence/head while holding SQLite's writer reservation, validates the
expected sequence and (for provenance events) expected head digest, and
inserts before committing. It also rejects duplicate event IDs and mismatched
provenance predecessor digests. Anchor appends enforce a strictly increasing
provenance sequence within each chain. Competing stale writers return
`false`; constraint and storage failures surface as exceptions.

This is local SQLite transactional serialization across independent
connections to the same database file. It is not distributed consensus,
cross-host coordination, or exactly-once execution.

## Schema and durability

Schema version 1 contains the provenance event, anchor, and signing-key event
tables and the key-history index. Migration is performed transactionally and
uses `PRAGMA user_version`; newer unknown versions fail closed. The adapter
uses WAL for file-backed databases, `synchronous=FULL`, foreign-key
enforcement, and a five-second busy timeout. Busy/locked errors are surfaced
to the host.

Use a local filesystem with reliable SQLite locking. Do not place an active
database on object storage or an unreliable network filesystem. Backups,
restore validation, encryption at rest, retention, and external tamper-evident
anchors remain host responsibilities.

## Operational diagnostics and maintenance

The adapter exposes an explicit, read-only `inspect()` operation. It reports
the schema version, journal mode, synchronous setting, busy timeout, row
counts for each append-only table, and SQLite `PRAGMA quick_check` result.
The quick check scans database structures and should be scheduled as an
operational diagnostic, not placed on the append hot path. Values are read in
separate statements; during concurrent writes, counts are advisory and are
not a transactionally consistent snapshot. A result other than `ok` should
trigger host-defined investigation and restore procedures, not an automatic
repair attempt.

WAL maintenance is explicit through `checkpointWal()`. The default
`passive` mode avoids waiting for readers; hosts may select `full`,
`restart`, or `truncate` as part of a controlled maintenance window. A
truncate checkpoint can wait on readers and must not be run automatically by
the adapter. The result reports busy status, WAL frame count, and checkpointed
frame count. A checkpoint is not a backup and does not replace a consistent
SQLite backup procedure.

Example:

```dart
final health = persistence.inspect();
if (!health.quickCheckPassed) {
  // Alert and follow the host's incident/restore runbook.
}

final checkpoint = persistence.checkpointWal();
if (!checkpoint.fullyCheckpointed) {
  // Record the incomplete checkpoint and retry under host policy.
}
```

The adapter exposes `backupTo(destinationPath)`, which uses SQLite's
`VACUUM INTO` to produce a consistent standalone snapshot using SQLite's own
locking and WAL machinery. The destination must not already exist. The adapter
does not encrypt, upload, or retain backups; hosts must protect the destination
and own backup lifecycle, off-host replication, and restore authorization.
After restore, run the provenance and anchor verifiers against independently
retained signed anchors.

The adapter does not delete, compact, or expire provenance records. Retention
must preserve append-only evidence and be implemented as an explicit,
externally governed archival policy.

## Validation strategy

The package tests exercise close/reopen durability, independent-connection
append races, the shared `PluginRecoveryProvenanceConformanceSuite` against
all three SQLite store views, stale-head rejection, duplicate key-history
sequence rejection, per-chain anchor sequence isolation, health diagnostics,
explicit WAL checkpoint behavior, competing writers in separate OS processes,
rollback after terminating a process with an open transaction, and a
`VACUUM INTO` backup/restore round trip. These are integration tests on the
test host's local filesystem; they do not establish power-loss durability,
filesystem-specific behavior, off-host backup integrity, or recovery from
hardware/storage failure. Hosts must still validate their production filesystem
and backup lifecycle against independently retained signed anchors.

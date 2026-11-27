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

## Validation strategy

The package tests exercise close/reopen durability, independent-connection
append races, stale-head rejection, duplicate key-history sequence rejection,
and per-chain anchor sequence isolation. These are adapter-level tests; hosts
should additionally run conformance tests against their production filesystem,
backup/restore process, and deployment topology.

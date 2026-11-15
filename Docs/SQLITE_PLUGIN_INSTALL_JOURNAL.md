# SQLite Plugin Installation Journal

The optional `alhambra_plugin_install_sqlite` package provides a durable
implementation of the runtime's `PluginInstallRecoveryJournal` contract.

## Storage model

Schema version 1 stores:

- `plugin_install_operation`: one current projection per operation ID,
  including the current status, timestamp, database revision, package identity,
  staging/destination handles, content hash and approval attribution.
- `plugin_install_event`: append-only snapshots of every accepted transition,
  uniquely keyed by operation ID and revision.

The current projection and history event are written in one SQLite transaction.
Every update uses `BEGIN IMMEDIATE`, including recovery claims. The adapter
uses an operation primary key and database revision to serialize independent
connections. `unresolved()` reads the current projection and excludes only
`committed`, `rolledBack` and `failed`; ambiguous statuses remain visible.

## Recovery compare-and-set

`compareAndSet` verifies the current operation ID, expected status, exact UTC
timestamp, and immutable plugin/version identity. The replacement timestamp
must advance beyond the expected timestamp. A successful claim increments the
database revision and appends its event atomically. Stale claims return false.

Approval identifiers are unique across the database's entire event history,
not merely the current projection. Keep one database per host audit scope, or
deliberately share it when approval identifiers must be globally unique across
hosts.

## Operational constraints

- Use a local filesystem with reliable SQLite locking. Network filesystems and
  object stores are outside the supported concurrency assumptions.
- The adapter enables WAL for file-backed databases, foreign keys and a
  five-second busy timeout.
- Back up and protect the database as security-sensitive audit data.
- Close the store during host shutdown and reopen it to resume reconciliation.
- The database is not a replacement for worker leases or filesystem ownership
  markers. The host must fence the original installer before recovery.
- SQLite cannot atomically commit a filesystem rename. Crash-safe staging,
  promotion, rollback and finalization remain filesystem-adapter obligations.
- The adapter does not establish exactly-once effects across the database and
  filesystem, nor does it implement archive canonicalization.

## Validation scope

The package tests cover reopen persistence, append-only history ordering,
concurrent CAS attempts over two connections, stale claims, approval-ID
uniqueness and terminal-state protection. Run the package's Dart tests in a
configured Flutter/Dart environment before production adoption.

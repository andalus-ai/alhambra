# Alhambra SQLite Plugin Installation Journal

This package provides `SqlitePluginInstallJournal`, a durable implementation of
`PluginInstallRecoveryJournal` for hosts that use SQLite.

## Guarantees

- Persists the current operation projection and an append-only transition event
  in the same SQLite transaction.
- Uses `BEGIN IMMEDIATE` for writes and recovery compare-and-set operations.
- Uses a monotonically increasing database revision for every accepted update.
- Rejects operation-ID reuse for a different plugin/version.
- Enforces approval-ID uniqueness within this database.
- Returns one current unresolved row per operation, excluding committed,
  rolled-back and failed terminal states.
- Supports closing and reopening a file-backed database to recover journal state.

## Usage

```dart
final journal = SqlitePluginInstallJournal('/var/lib/my-host/plugin-installs.sqlite');
final installer = TransactionalPluginInstaller(
  verifier: verifier,
  preflight: preflight,
  fileSystem: fileSystem,
  installedStore: installedStore,
  journal: journal,
);

// On host shutdown:
journal.close();
```

Use one database per host audit scope unless the host deliberately shares the
approval-ID namespace. The database should reside on a local filesystem with
reliable SQLite locking; network filesystems and object stores are not supported
by this adapter's guarantees.

## Schema and operations

Schema version 1 contains a current operation table and append-only event
history. `write` atomically inserts or advances the operation revision.
`compareAndSet` checks operation ID, expected status, exact UTC timestamp and
immutable plugin/version identity before appending a new revision. The
replacement timestamp must be later than the expected timestamp, preventing
same-timestamp ABA claims. Approval IDs are unique across the database.

## Explicit limitations

This is a durable journal, not a complete crash-safe installer. It does not
provide filesystem staging/promotion, worker leases/fencing, archive
canonicalization, or atomic transactions across SQLite and the filesystem.
The host must fence a live installer before recovery, and filesystem adapters
must independently prove operation ownership and idempotent crash recovery.
SQLite durability depends on filesystem, journal mode, synchronous settings,
backup and operational configuration. Do not interpret this adapter as
exactly-once filesystem effects.

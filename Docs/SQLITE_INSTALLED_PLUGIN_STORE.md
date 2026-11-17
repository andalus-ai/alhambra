# SQLite Fenced Installed-Plugin Store

The optional `alhambra_plugin_install_sqlite` package provides
`SqliteInstalledPluginStore`, a durable implementation of
`FencedTransactionalInstalledPluginStore`.

## Guarantees

- Stores installed plugin identity, semantic version, content hash, publisher
  metadata, install timestamp and install path.
- Enforces one installed record per plugin ID with a SQLite primary key.
- Implements atomic create-if-absent and compare-and-remove operations.
- Persists the highest accepted fencing token per installation operation.
- Checks the exact current token in the same `BEGIN IMMEDIATE` transaction as
  every fenced create or remove.
- Retains the stable operation ID that created each transactional record.
- Allows a recovery worker with a newer token for the same operation to
  compensate for its interrupted install.
- Prevents a different operation from removing that record, even if its
  plugin metadata happens to match.
- Prevents legacy unfenced `save` and `remove` calls from overwriting or
  deleting operation-owned records.

## Usage

The store may share a database file with the journal and lease adapters. Each
adapter owns a separate SQLite connection:

```dart
final databasePath = '/var/lib/alhambra/plugin-installs.sqlite';

final installedStore = SqliteInstalledPluginStore(databasePath);
final journal = SqlitePluginInstallJournal(databasePath);
final leases = SqlitePluginInstallOperationLeaseStore(databasePath);

final installer = TransactionalPluginInstaller(
  verifier: verifier,
  preflight: preflight,
  fileSystem: fileSystem,
  installedStore: installedStore,
  journal: journal,
  leaseStore: leases,
  workerId: workerId,
);

// Close all three adapters during host shutdown.
```

## Ownership and fencing

The store maintains two related but distinct facts:

1. **Operation ownership** is the stable operation ID persisted on the installed
   record. It identifies which installation transaction created the record.
2. **Mutation authority** is the highest fencing token persisted for that
   operation. A write or compensation must present that exact token.

A recovery worker first advances the operation fence. It can then remove a
record created by the same operation using the newer token. An old worker's
token is rejected. A different operation cannot remove the record.

Fences are retained after record removal and operation completion. Operation
IDs must therefore be unique and never intentionally reused.

## Compatibility behavior

- `createIfAbsent` creates an unowned record for legacy callers.
- `removeIfMatches` removes only an unowned record whose complete persisted
  metadata matches the supplied record.
- `save` may insert or update unowned records, but rejects overwriting a
  transaction-owned record.
- `remove` may remove an unowned record, but rejects transaction-owned rows.
- Transaction-owned rows must be changed through the fenced methods.

This preserves the existing `InstalledPluginStore` contract while ensuring
unfenced compatibility calls cannot bypass transactional ownership.

## Schema and operations

The adapter creates two additive tables without changing SQLite
`PRAGMA user_version`, because the same database may be shared with the
journal adapter:

- `alhambra_installed_plugin`: current installed record and stable operation
  owner.
- `alhambra_installed_plugin_fence`: highest accepted token per operation.

Writes use `BEGIN IMMEDIATE` to serialize competing local SQLite connections.
File-backed stores enable WAL, a five-second busy timeout and
`synchronous = FULL`.

## Limits

- This is a local SQLite adapter, not a multi-region distributed database.
- The adapter does not make the journal, filesystem and installed records one
  atomic transaction. Recovery remains a host-orchestrated saga.
- It does not implement filesystem fencing; the filesystem must independently
  enforce the same operation token.
- Lease expiry and token acquisition still rely on the host-supplied clock.
- It does not provide exactly-once external effects or automatic retry.

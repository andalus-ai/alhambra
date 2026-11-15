# Alhambra SQLite Plugin Installation Persistence

This package provides durable SQLite adapters for plugin installation:
- `SqlitePluginInstallJournal` implements `FencedPluginInstallRecoveryJournal`.
- `SqlitePluginInstallOperationLeaseStore` implements
  `PluginInstallOperationLeaseStore`.

## Guarantees

- Persists the current operation projection and append-only transition event in
  one transaction.
- Uses `BEGIN IMMEDIATE` for journal writes, recovery CAS, and lease changes.
- Persists the highest accepted operation fencing token and rejects journal
  writes/CAS claims carrying stale or missing tokens once fencing is enabled.
- Persists lease ownership and monotonically increasing fencing tokens across
  release, expiry, close and reopen.
- Serializes independent SQLite connections competing for the same operation.
- Retains approval-ID uniqueness and ordered operation history.
- Supports existing schema-v1 journal databases through an additive v2
  migration.

## Usage

```dart
final journal = SqlitePluginInstallJournal('/var/lib/host/plugin-installs.sqlite');
final leases = SqlitePluginInstallOperationLeaseStore(
  '/var/lib/host/plugin-installs.sqlite',
);

final installer = TransactionalPluginInstaller(
  verifier: verifier,
  preflight: preflight,
  fileSystem: fileSystem,
  installedStore: installedStore,
  journal: journal,
  leaseStore: leases,
  workerId: workerId,
);

/// On host shutdown:
leases.close();
journal.close();
```

The journal and lease store may share one database file. Each store owns its
connection; close both during host shutdown. Use a local filesystem with
reliable SQLite locking. WAL and a five-second busy timeout are enabled for
file-backed stores. Keep the database protected as security-sensitive audit
and installation state.

## Fencing behavior

Call `advanceFence(operationId, fencingToken)` before any operation writes.
Once a fence row exists, journal `write` and `compareAndSet` require the exact
currently registered token. Advancing to a higher token makes all prior
workers stale. Lower tokens cannot move the fence backwards. Fence state is
retained after operation completion so an operation ID cannot accidentally
reuse an earlier token.

The lease store uses an atomic per-operation row. A successful new acquisition
after expiry/release increments the token. Re-acquisition by the same owner
while its lease is active is idempotent. Renew/release require the exact owner
and token. The API accepts a host-supplied timestamp; multi-host deployments
must provide a consistent authoritative clock (preferably database-derived).

## Explicit limitations

- This package does not provide a production filesystem adapter. Staging,
  extraction, promotion, rollback and finalization still require a
  `FencedPluginInstallFileSystem` implementation that checks the token
  atomically with every mutation.
- The installed-plugin store must independently implement
  `FencedTransactionalInstalledPluginStore`.
- SQLite journal/lease transactions do not form a distributed transaction with
  the filesystem or installed-record store.
- A lease expiry alone does not fence a paused worker; every side-effecting
  adapter must persist and check the higher token atomically.
- The lease API uses caller-supplied time. Unsynchronized host clocks can
  undermine expiry decisions; use a shared authoritative time source.
- Local SQLite locking assumptions do not cover network filesystems or
  multi-region distributed coordination.
- This does not provide exactly-once external effects or automatic retry of
  ambiguous operations.

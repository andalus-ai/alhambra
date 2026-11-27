# Alhambra SQLite Plugin Installation Persistence

This package provides durable SQLite adapters for plugin installation:
- `SqliteInstalledPluginStore` implements `FencedTransactionalInstalledPluginStore`.
- `SqlitePluginInstallJournal` implements `FencedPluginInstallRecoveryJournal`, `PluginInstallManualReconciliationStore` and `PluginInstallAuditStore`.
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
- Persists append-only operator manual-reconciliation evidence and atomically
  closes ambiguous recovery operations using compare-and-set.
- Supports schema-v1 and schema-v2 journal databases through additive v2/v3
  migrations.

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


## Installed-plugin records

Use `SqliteInstalledPluginStore` with the same database path as the journal
and lease store:

```dart
final installedStore = SqliteInstalledPluginStore(databasePath);
final journal = SqlitePluginInstallJournal(databasePath);
final leases = SqlitePluginInstallOperationLeaseStore(databasePath);
```

The installed-record adapter persists one row per plugin ID, including
publisher metadata and the operation ID that created a transactional record.
It atomically enforces the current fencing token on create and compensating
remove operations. A recovery worker may remove a record created by the same
operation after advancing to a newer token; a different operation cannot
remove it. Legacy unfenced APIs are restricted to unowned rows and cannot
overwrite or delete transaction-owned records.

See [the installed-store design and guarantees](../../Docs/SQLITE_INSTALLED_PLUGIN_STORE.md).


## Manual recovery reconciliation

For an operation left in `recoveryStarted` or `needsReconciliation`, inspect the actual filesystem and installed-plugin record before asking an authorized operator to record a conclusion. The journal implements `PluginInstallManualReconciliationStore`:

```dart
final recorded = await journal.reconcileManually(
  operationId: operationId,
  expectedUpdatedAt: unresolvedEntry.updatedAt,
  resolution: PluginInstallManualResolution.absentAndClean,
  resolutionId: uniqueResolutionId,
  operatorId: authenticatedOperatorId,
  evidenceSummary: 'Verified destination, staging and installed record are absent; see incident INC-123.',
  resolvedAt: clock.now(),
);
```

A successful call appends an immutable reconciliation record and a journal history event in the same SQLite transaction, then moves the operation to terminal `manuallyReconciled`. It does not modify filesystem contents or installed-plugin records. The caller must provide an authenticated operator identity and evidence summary; do not treat this API as proof that the operator's conclusion is correct. Retrieve the audit trail with `manualReconciliations(operationId)`.

## Installation audit queries

The journal exposes a bounded read-only audit projection through
`PluginInstallAuditStore`. The default page size is 100 and the maximum is
500; offsets are limited to 0–100,000. Time filters use UTC instants, with
`from` inclusive and `to` exclusive.

```dart
final events = await journal.queryAudit(PluginInstallAuditQuery(
  pluginId: 'com.example.editor',
  status: PluginInstallJournalStatus.manuallyReconciled,
  from: incidentStartedAt,
  to: incidentEndedAt,
  limit: 100,
));

for (final event in events) {
  // Use operationId, pluginId, status, occurredAt, operatorId and approvalId
  // to populate a host-owned audit timeline.
}
```

Results are ordered newest-first, with event ID as a deterministic tie-breaker.
Use operation ID filtering and advance the offset by the returned row count to retrieve a complete operation-specific timeline across pages. The
projection deliberately omits filesystem paths, staging handles, content
hashes and package contents. Manual-resolution records are joined to their
corresponding journal transition so they appear exactly once; evidence summaries
should contain only a protected incident reference or similarly non-secret
description. Hosts remain responsible for authentication, authorization,
retention, export policy and redaction appropriate to their deployment.

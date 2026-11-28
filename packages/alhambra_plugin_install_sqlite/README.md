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
- Supports schema-v1 through schema-v4 journal databases through additive migrations to schema v5.

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

## Audit archival and retention

Retention is opt-in through `PluginInstallAuditRetentionPolicy`; the host chooses the duration and schedules the two-step archival operation. The default policy is disabled. The SQLite
journal previews only events older than the requested cutoff whose current
operation projection is terminal (`committed`, `rolledBack`, `failed` or
`manuallyReconciled`). Ambiguous and active operations are never eligible.

```dart
final policy = PluginInstallAuditRetentionPolicy(
  retentionPeriod: const Duration(days: 90),
  batchSize: 500,
  enabled: true,
);
final retentionCutoff = policy.cutoffAt(clock.now());
if (retentionCutoff != null) {
  final candidates = await journal.previewPrunableAudit(
    before: retentionCutoff,
    limit: policy.batchSize,
  );
  if (candidates.isNotEmpty) {
    final batch = PluginInstallAuditArchiveBatch(
      batchId: uniqueBatchId,
      createdAt: clock.now(),
      cutoff: retentionCutoff,
      records: candidates,
    );

    // The archive adapter persists the full batch and verifies its durable
    // representation before it returns a receipt.
    final receipt = await archiveStore.archiveAndVerify(batch);
    await journal.pruneArchivedAudit(
      batch: batch,
      receipt: receipt,
      archiveStore: archiveStore,
    );
  }
}
```

Pruning requires the original previewed batch alongside its receipt. It checks that batch ID, cutoff, record count and exact event-ID set match before verifying the archive and opening a SQLite transaction. The
transaction then verifies every referenced event still exists, belongs to a
terminal operation, and is older than the receipt cutoff. It records the
archive manifest and exact event IDs before deleting those local event rows.
Manual-reconciliation evidence joined to an archived event is pruned in the
same transaction. A receipt cannot be applied twice. If verification or any
eligibility check fails, no local event is deleted.

The archive adapter owns durable storage, digest/signature generation, key
management, access controls and restore procedures. Alhambra does not claim a
particular cryptographic algorithm or cloud archive implementation. Treat
archive receipts and archive contents as security-sensitive records.

This retention operation removes local transition history only. It deliberately
retains the current operation projection, approval identity records, fencing
state and installed-plugin records; those have separate lifecycle and
retention requirements. Hosts should keep archive storage independently
available and tested for restore before enabling aggressive local retention.

# Transactional Installation Crash-Recovery Conformance

This document defines the crash/restart scenarios exercised by the durable
plugin-installation adapters. It describes the tested local SQLite +
filesystem saga; it does not claim a distributed atomic transaction.

## Adapter set

The integration tests use the concrete host adapters together:

- `SqlitePluginInstallJournal` for the durable operation projection and history.
- `SqlitePluginInstallOperationLeaseStore` for persisted lease ownership and
  monotonically increasing fencing tokens.
- `SqliteInstalledPluginStore` for fenced installed-record creation/removal.
- `LocalPluginInstallFileSystem` for fenced staging, promotion, ownership
  evidence, rollback and finalization.

The SQLite adapters may share one database file. The local filesystem adapter
persists its operation fencing state alongside its staging and destination
metadata.

## Recovery decision matrix

| Interruption point / durable evidence | Expected planner action | Required outcome |
| --- | --- | --- |
| Promotion intent recorded; destination promoted; no installed record | `rollbackPromotion` | Remove only the destination proven to belong to the operation; terminal journal state is `rolledBack`. |
| Installed record saved; destination exists and record matches journal | `finalizePromotion` | Retain the destination and installed record; terminal journal state is `committed`. |
| Stale installer resumes after a recovery worker takes over | No stale mutation is accepted | Old-token journal writes, filesystem mutations and installed-record creation are rejected. |
| Normal transactional installation completes | No unresolved finding remains | Installed record and promoted destination exist; journal is terminal `committed`. |
| Evidence is contradictory, incomplete or owned by another operation | `manualReview` | No destructive automatic action is permitted. |
| Recovery claim persisted; side effect completed; terminal journal update unavailable | `manualReview` after restart | Preserve the durable `recoveryStarted` claim; do not replay the side effect. |

The recovery planner is read-only. The executor requires explicit operator
identity and approval ID, re-inspects the current evidence, claims the journal
entry, and obtains a fresh operation lease before performing a recovery action.

## Test coverage

The integration suite covers:

1. A promoted destination without an installed record, followed by a newer
   recovery worker taking over and rolling the destination back.
2. A promoted destination with a matching installed record, followed by
   closing and reopening the SQLite adapters, token takeover, and approved
   finalization.
3. A complete successful install using the concrete SQLite journal, lease
   store, installed-plugin store and local filesystem.
4. A full adapter reopen after promotion, followed by a new worker acquiring a
   higher token. The stale worker is then challenged against all three fenced
   mutation surfaces (journal, filesystem and installed-plugin store), before
   the recovery worker safely rolls back the interrupted operation.
5. A journal outage after the recovery side effect, followed by restart and
   confirmation that a second automated execution is rejected. An operator
   then records an explicit `absentAndClean` conclusion, which closes the
   journal and appends a durable audit record without changing filesystem or
   installed-record state.

The focused integration tests live in
`packages/alhambra_plugin_install_sqlite/test/plugin_install_recovery_integration_test.dart`;
recovery interruption fault-injection coverage lives in
`packages/alhambra_plugin_install_sqlite/test/plugin_install_recovery_interruption_test.dart`;
manual reconciliation CAS, audit persistence and schema-reopen coverage lives in
`packages/alhambra_plugin_install_sqlite/test/sqlite_plugin_install_manual_reconciliation_test.dart`.
Adapter-specific persistence and concurrency tests remain in their respective
package test directories.

## Operator-controlled manual reconciliation

An operation left in `recoveryStarted` or `needsReconciliation` is not eligible
for automated recovery. A host operator must first inspect the journal history,
filesystem ownership snapshot, destination/staging state, and installed-plugin
record. The host should preserve the inspection evidence in its incident or
change-management system.

`PluginInstallManualReconciliationStore.reconcileManually` provides a durable,
compare-and-set closure for this case. The operator supplies a unique resolution
ID, identity, a bounded evidence summary, timestamp, and one of three explicit
conclusions: `installedAndVerified`, `absentAndClean`, or
`residualStateAccepted`. The SQLite implementation atomically appends the audit
record, adds a journal history event, and transitions the operation to
`manuallyReconciled`. A stale timestamp, an operation outside the ambiguous
recovery states, a reused resolution ID, or a stale fencing token is rejected.

This API records the operator's conclusion only. It does not delete files,
restore backups, create/remove installed records, or prove that the supplied
evidence is true. Any repair must be a separate host-controlled action with
its own authorization and audit. The evidence summary should reference a
protected incident record rather than include secrets or package contents.
`manuallyReconciled` is terminal and excluded from unresolved recovery scans.

## Operational requirements

- A host must use a stable, non-reused operation ID for each installation.
- A host must coordinate leases using a durable store and an authoritative
  clock when workers can run on different machines.
- A host must not remove an abandoned filesystem lock merely because it is old.
  It must first prove that the previous worker cannot continue mutating.
- Every recovery action must be based on a fresh inspection and explicit host
  approval. The planner's output is a proposal, not authorization.
- The SQLite journal, lease store and installed-plugin store each fence their
  own mutations. The local filesystem independently enforces its current token.
- Keep the ownership marker in the installed tree until the installation
  lifecycle no longer needs recovery ownership evidence.

## Guarantees and non-goals

The tests establish recoverability across the documented local SQLite and
local-filesystem boundaries, and verify that a stale fencing token cannot
mutate those adapters after takeover.

They do **not** establish:

- one atomic commit spanning SQLite and the filesystem;
- exactly-once behavior for arbitrary external side effects;
- distributed-filesystem lock or rename semantics;
- multi-host safety without a shared authoritative lease clock and a storage
  system whose durability and locking semantics meet the host's requirements;
- automatic recovery without operator approval.

If recovery itself is interrupted after its durable `recoveryStarted` claim,
the operation is deliberately surfaced for manual reconciliation rather than
blindly replaying a potentially completed side effect.

## Installation audit inspection

Hosts can expose a read-only installation timeline by adapting
`PluginInstallAuditStore.queryAudit`. The SQLite implementation supports
bounded pages (1–500 records; default 100; offset 0–100,000), ordered newest-first with a stable
event-ID tie-breaker. Filters include operation ID, plugin ID, transition
status, operator ID, and a UTC time range (`from` inclusive, `to` exclusive).
The database maintains indexes for plugin/time, status/time, operator/time,
and general time-order scans.

The audit projection includes operation/plugin/version identity, transition,
revision, timestamp, operator/approval references, failure code and fencing
token. It intentionally excludes filesystem paths, staging handles, package
hashes and package contents. Manual reconciliation metadata is joined to its
single corresponding journal transition; it is not emitted as a duplicate
event. Evidence summaries should point to protected incident records and must
not contain credentials, package data or other secrets.

This is a persistence/query contract, not an administrative API or dashboard.
The host must authenticate and authorize callers, apply tenant or workspace
scope before invoking the store, decide retention and export policy, and
protect audit data at rest and in transit. Offset pagination is intended for
bounded operational inspection; hosts needing long-running exports should
capture a stable time window and apply their own export/retention controls.

## Audit archival and retention guarantees

`PluginInstallAuditRetentionPolicy` is opt-in (disabled by default) and lets the host set a retention duration and batch size. The host computes the UTC cutoff and schedules archival. `PluginInstallAuditRetentionStore.previewPrunableAudit` returns a bounded set
of transition records older than a supplied UTC cutoff, but only when the
operation's current projection is terminal. Active operations and operations
in `recoveryStarted` or `needsReconciliation` are never eligible. This is a
preview, not a deletion.

The host passes the complete preview to its configured
`PluginInstallAuditArchiveStore.archiveAndVerify`. That adapter must durably
persist the complete batch and verify the archived representation before
issuing a receipt containing the archive identity, digest, cutoff, count and
exact event IDs. The host then passes that receipt back to
`pruneArchivedAudit`. SQLite verifies the receipt through the configured
archive adapter and, in one transaction, rechecks that every referenced event
still exists, is older than the cutoff and belongs to a terminal operation.
Only then are the archive manifest and event IDs recorded and local event rows
deleted. Manual-reconciliation evidence associated with those events is deleted
in the same transaction. Replayed receipts are rejected.

The archive adapter is responsible for the integrity algorithm, signing-key
management, access control, durable storage and restore testing. The SQLite
adapter does not claim cryptographic immutability by itself. If archive
verification fails, a referenced event is missing, or an operation is no
longer terminal, the entire prune transaction fails without deleting any
local event.

Retention removes local transition history only. It does not remove current
operation projections, approval identity records, fencing state, or installed
plugin records. Those are operational state with separate lifecycle rules.
Hosts must not enable local pruning until the archive restore path has been
tested and operational ownership for retention is explicit.

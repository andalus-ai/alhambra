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

The focused integration tests live in
`packages/alhambra_plugin_install_sqlite/test/plugin_install_recovery_integration_test.dart`.
Adapter-specific persistence and concurrency tests remain in their respective
package test directories.

## Operator-controlled manual reconciliation\n\nAn operation left in `recoveryStarted` or `needsReconciliation` is not eligible\nfor automated recovery. A host operator must first inspect the journal history,\nfilesystem ownership snapshot, destination/staging state, and installed-plugin\nrecord. The host should preserve the inspection evidence in its incident or\nchange-management system.\n\n`PluginInstallManualReconciliationStore.reconcileManually` provides a durable,\ncompare-and-set closure for this case. The operator supplies a unique resolution\nID, identity, a bounded evidence summary, timestamp, and one of three explicit\nconclusions: `installedAndVerified`, `absentAndClean`, or\n`residualStateAccepted`. The SQLite implementation atomically appends the audit\nrecord, adds a journal history event, and transitions the operation to\n`manuallyReconciled`. A stale timestamp, an operation outside the ambiguous\nrecovery states, a reused resolution ID, or a stale fencing token is rejected.\n\nThis API records the operator's conclusion only. It does not delete files,\nrestore backups, create/remove installed records, or prove that the supplied\nevidence is true. Any repair must be a separate host-controlled action with\nits own authorization and audit. The evidence summary should reference a\nprotected incident record rather than include secrets or package contents.\n`manuallyReconciled` is terminal and excluded from unresolved recovery scans.\n\n## Operational requirements

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

# Transactional Plugin Installation

`TransactionalPluginInstaller` coordinates package verification, host
preflight, bounded extraction into an isolated staging area, reversible
promotion and installed-record persistence. It installs package files only;
it never loads or executes downloaded Dart code or activates a plugin.

## Required host adapters

A host supplies four contracts:

- `PluginPackageVerifier`: verifies package metadata, payload integrity and
  publisher signature according to host trust policy.
- `PluginInstallPreflight`: checks host API/platform/edition compatibility and
  resolves required dependencies without executing plugin code.
- `PluginInstallFileSystem`: creates private staging, writes files, promotes
  staged content and supports rollback until finalization.
- `TransactionalInstalledPluginStore`: provides atomic create-if-absent and
  compare-and-remove operations so a failed install cannot overwrite or delete
  a concurrent installation.
- `PluginInstallJournal`: durably records operation state before the
  corresponding external side effect and exposes unresolved operations.

Packages must implement `PluginPackageArchive` to enumerate entries. The
installer reads each file payload through the existing package payload API.

## Transaction sequence

1. Write `verificationStarted` to the journal.
2. Verify package integrity and publisher trust.
3. Write `verified`; run host preflight before creating staging.
4. Create an isolated staging handle and journal it.
5. Journal extraction, validate each path and entry kind, then stream files
   into staging under per-file, total-byte and entry-count limits.
6. Resolve and journal the intended destination, then promote staged content while retaining a rollback capability.
7. Persist the installed-plugin record.
8. Finalize the filesystem promotion and write `committed`.

The installer serializes concurrent operations for the same plugin ID within
one instance. The installed-record adapter's atomic create-if-absent operation
is the cross-instance/process uniqueness boundary. The in-memory reference
store is only single-process. An already-installed ID is rejected; upgrades
require a separate explicit transaction design rather than implicit replacement.

## Archive safety

The installer rejects absolute paths, drive-prefixed paths, backslashes,
NUL bytes, empty/dot/dot-dot path segments, duplicate paths, file/directory
collisions, symbolic links and special entries. It enforces entry-count,
per-file and aggregate uncompressed-byte limits while streaming.

The filesystem adapter must independently enforce containment beneath its
staging root, create parent directories safely, avoid following pre-existing
symlinks, and write with exclusive creation. Destination resolution must be
side-effect free. Promotion must not overwrite unrelated existing content;
rollback must be safe after an ambiguous promotion error and must restore a
previous destination or remove the new tree. Runtime path checks are defense
in depth, not a substitute for safe filesystem primitives.

## Rollback and recovery

If an operation fails before promotion, the staging area is discarded. If
promotion has occurred, the adapter must restore the previous filesystem
state using its retained rollback information. If an installed record was
written, it is removed during rollback.

If rollback or journal updates fail, the installer reports
`reconciliationRequired` and writes `needsReconciliation` when possible. It
does not blindly retry filesystem operations. Hosts should inspect unresolved
journal entries and reconcile them against the actual filesystem and installed
record store before allowing another operation for that plugin.

## Transaction guarantees and limitations

This is a saga across host adapters, not a distributed atomic transaction.
The filesystem and installed-record store cannot be assumed to share one
atomic commit. A durable journal and reversible promotion are therefore
required to recover ambiguous interruption windows.

The repository supplies contracts and a coordinator, not a production archive
reader, concrete filesystem adapter, durable journal or durable installed
record store. The default operation ID is unique only within one installer
instance/time sequence; production hosts should inject a globally unique ID
factory and enforce uniqueness in the durable journal. An adapter claiming atomic promotion must prove it with
platform-specific integration tests. In-memory test doubles do not establish
crash durability, cross-process serialization or filesystem atomicity.

Plugin activation remains a separate host-controlled lifecycle operation after
installation has committed.

## Installation recovery and reconciliation

### Read-only planning

`PluginInstallRecoveryPlanner.inspect()` reads unresolved journal entries,
calls the filesystem adapter's read-only `inspectOperation`, and compares the
destination with the installed record. It produces immutable findings and
never changes journal, filesystem or installed-record state.

The planner proposes only narrowly supported cases:

- **discardStaging** — staging exists, destination does not, and no installed
  record exists.
- **rollbackPromotion** — destination exists, the adapter proves operation
  ownership, rollback remains available, and no installed record exists.
- **finalizePromotion** — destination ownership and the installed record agree
  on plugin ID, version, content hash and destination.
- **markFailed** — no staging, destination or installed record exists and the
  journal shows the operation stopped before staging began.
- **manualReview** — ownership, record identity, metadata or prior recovery
  outcome is ambiguous.

The journal must persist the package content hash. The filesystem inspection
must prove staging and destination ownership using operation-bound metadata
(for example a durable operation marker); a matching path string is not proof
of ownership. The planner treats an interrupted rollback or recovery claim as
manual review because its previous side effects may be incomplete.

### Explicitly approved execution

The host must explicitly call
`PluginInstallRecoveryExecutor.execute(finding, approvedBy:, approvalId:)`.
Before side effects, the host must fence the original installer worker or
prove its durable operation lease has expired. A recovery scan must never race
a live installer. The executor re-reads the unresolved journal entry,
re-inspects filesystem and installed metadata, compares them with the finding,
and atomically claims the operation using
`PluginInstallRecoveryJournal.compareAndSet`.

The claim records the operator identity and approval ID in the journal before
performing one action. Approval IDs must be unique within the host's audit
scope; the durable journal adapter should enforce uniqueness and retain the
attribution. Journal compare-and-set must fence both the expected status and
its observed update timestamp/revision, and `unresolved()` must return only
the latest non-terminal entry for each operation. The executor then writes a terminal outcome with another
compare-and-set. If a side effect or outcome write fails, the journal remains
`needsReconciliation` or `recoveryStarted`; another worker must not blindly
repeat the action. A new host inspection and explicit resolution are required.

### Production adapter requirements

- `inspectOperation` is read-only and must not create, remove, rename or repair files.
- Operation ownership must be derived from trusted durable provenance.
- Journal compare-and-set must be atomic across processes and enforce one
  current record per operation ID.
- The adapter must define whether rollback, finalize and discard are idempotent
  after process interruption and ambiguous return values.
- The journal must retain approval attribution and operation history according
  to the host's audit-retention policy.
- Filesystem and journal adapters need crash-injection and multi-process tests.
  In-memory tests do not establish those guarantees.

The recovery executor does not activate plugins, rerun extraction, overwrite
installed records, or automatically retry ambiguous operations.

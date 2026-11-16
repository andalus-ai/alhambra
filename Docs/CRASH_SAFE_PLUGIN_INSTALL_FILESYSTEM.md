# Crash-safe Local Plugin Installation Filesystem

The optional `alhambra_plugin_install_filesystem` package implements the
`FencedPluginInstallFileSystem` contract using local directories and files.

## Directory layout

```text
<root>/
  plugins/
    <plugin-id>/
      <version>/
        .alhambra-install-owner.json
        <plugin payload>
  .alhambra-install-state/
    staging/
      <operation-key>/
    operations/
      <operation-key>.json
    locks/
      <operation-key>/
```

The operation key is a URL-safe Base64 encoding of the operation ID. State
metadata and staging directories are kept outside the plugin payload. The
ownership marker is deliberately retained in the installed directory so the
host can prove which operation promoted the tree after a process crash. This
filename is reserved and rejected in archive paths.

The marker records stable operation/plugin ownership, not current worker authority.
Its original fencing token is diagnostic only: a recovery worker with a newer
registered token must still be able to prove that the same operation created
the destination. Every mutation is separately authorized by the current
fencing token. The marker is host metadata and is not part of the package
payload or the package's signed content hash.

## Mutation protocol

Every mutation obtains an exclusive operation lock directory, reads the
persisted highest fencing token, and checks exact token equality before
touching files. The lock serializes multiple processes using the same local
root. Advancing a fence is monotonic: a lower token is rejected and an equal
token is idempotent.

The adapter fails closed if a lock directory already exists. A crash can leave
a lock behind; automatically stealing it based on age would allow a paused
worker to race a new owner. The host must reconcile the operation and prove
that the old worker cannot continue before removing an abandoned lock.

Staging files are written with size limits and exclusive path checks. Symlinks,
absolute paths, traversal segments, special path forms and the reserved owner
marker are rejected. Existing staged files and destination trees are not
overwritten.

Promotion writes ownership evidence and persists the `promoting` phase before
renaming the staging directory to the final destination. If the process stops
after rename but before the journal records promotion, read-only inspection
can still prove ownership and report rollback availability. Finalization
records a finalized state but retains the ownership marker, allowing recovery
to safely re-run finalization when the journal commit was interrupted.

## Recovery and integration

`inspectOperation` does not repair or mutate files. It verifies operation and
plugin identity, staging handle and destination path, and reports staging,
destination ownership and rollback availability.

Use this adapter together with:
- `SqlitePluginInstallJournal` implementing
  `FencedPluginInstallRecoveryJournal`;
- `SqlitePluginInstallOperationLeaseStore` for durable worker ownership;
- an implementation of `FencedTransactionalInstalledPluginStore`.

The installer must register the lease fencing token with all three mutation
adapters before installation side effects begin. Every adapter independently
checks the token; a lease check alone is not sufficient.

## Limits and safety notes

- Local single-host filesystem semantics only; no network filesystem or
  multi-region coordination is claimed.
- Directory rename is atomic only under the supported same-filesystem
  assumption.
- The per-operation lock is a filesystem coordination primitive, not a
  distributed transaction. A stale lock requires explicit host reconciliation.
- The filesystem, SQLite journal and installed-record store do not share one
  atomic transaction. A crash between systems still requires journal-driven
  recovery and host approval.
- This is not exactly-once execution and does not automatically retry
  ambiguous external side effects.
- The adapter does not implement package archive parsing or cryptographic
  verification; those remain separate host/package responsibilities.

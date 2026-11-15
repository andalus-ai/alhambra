# SQLite Plugin Installation Journal and Leases

The optional `alhambra_plugin_install_sqlite` package provides durable SQLite
implementations for installation recovery journaling and worker leases.

## Storage model

The journal schema is version 2. It stores:
- `plugin_install_operation`: current operation projection, including revision,
  status, package identity, timestamps, recovery metadata and fencing token.
- `plugin_install_event`: append-only snapshots of accepted transitions,
  including the fencing token used for each transition.
- `plugin_install_fence`: highest accepted fencing token per operation ID.

The lease adapter stores `plugin_install_lease`, one current ownership row per
operation. It retains the last fencing token even after release or expiry, so
the next successful acquisition increments rather than reuses the token.
The lease table is additive and can share the same SQLite database file as the
journal; it does not use the database-global `PRAGMA user_version`.

The current projection and history event are committed in one transaction.
Journal writes, recovery claims and lease mutations use `BEGIN IMMEDIATE` to
serialize independent SQLite connections. Existing schema-v1 journal
databases are upgraded by adding the token columns and fence table.

## Fencing and recovery claims

Call `advanceFence(operationId, fencingToken)` before work starts. It
atomically persists the highest accepted token. Once a fence exists, journal
`write` and `compareAndSet` accept only that exact token. A stale worker
cannot append an event or claim recovery after a higher token has registered.

The lease store serializes acquisition, renewal and release per operation ID.
A different owner cannot acquire an unexpired lease. A new acquisition after
expiry/release receives a strictly higher token. Same-owner reacquisition
during an active lease returns the existing lease without minting a token.
Renewal requires the exact owner/token and a lease that has not expired.

The lease API accepts a timestamp supplied by the host. For multi-host
deployments, provide a shared authoritative clock (ideally database-derived);
unsynchronized worker clocks are not safe for lease expiry decisions.

## Operational constraints

- Use a local filesystem with reliable SQLite locking; network filesystems and
  object stores are outside the supported concurrency assumptions.
- File-backed databases enable WAL, foreign keys where applicable, full
  synchronous durability and a five-second busy timeout.
- Protect and back up the database as security-sensitive installation/audit
  state. Close both store connections during host shutdown.
- The lease store and journal may share one database file but maintain separate
  connections and schema responsibilities.
- The filesystem must independently implement
  `FencedPluginInstallFileSystem` and atomically reject stale tokens for every
  mutation. The installed-record store must implement
  `FencedTransactionalInstalledPluginStore`.
- SQLite cannot atomically commit a filesystem rename or installed-record
  mutation. This package does not provide a distributed transaction, crash-safe
  filesystem adapter, exactly-once external effects, or automatic retries of
  ambiguous operations.

## Validation scope

Tests cover journal reopen/history, independent-connection CAS contention,
stale fenced writes and CAS, durable lease token progression across reopen,
competing lease acquisition, same-owner idempotency and stale renewal. Run
Dart tests, formatting and static analysis in a configured environment before
production adoption.

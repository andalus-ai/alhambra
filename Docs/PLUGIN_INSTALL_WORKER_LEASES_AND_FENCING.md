# Plugin Installation Worker Leases and Fencing

This phase adds a storage-neutral lease contract and requires fence-aware
adapters when the transactional installer or recovery executor is configured
with a lease store.

## Lease model

`PluginInstallOperationLeaseStore` coordinates one owner per operation ID.
A lease contains an owner ID, acquisition/expiry timestamps and a monotonically
increasing fencing token.

- `acquire` returns null while another owner has an unexpired lease.
- Re-acquiring as the same owner is idempotent and does not mint a new token.
- `renew` succeeds only for the exact current owner/token pair before expiry.
- `release` only releases the exact owner/token pair.
- Expired/reacquired operations receive a strictly larger token.

The token counter must survive process restart in a production implementation.
Lease-store operations must be atomic/linearizable per operation ID.

## Fence-aware adapters

A lease alone is not enough: a paused worker may resume after its lease expires.
Therefore lease-enabled installation fails closed unless all three adapters
implement their fenced contracts:

- `FencedPluginInstallJournal`: atomically advances the operation's highest
  accepted token and rejects stale tokens on every journal write.
- `FencedPluginInstallFileSystem`: atomically advances the token in
  operation-owned filesystem metadata; staging handles carry the token and
  every mutating filesystem operation rejects older tokens.
- `FencedTransactionalInstalledPluginStore`: registers the token and checks
  it atomically for create/remove operations.

Before starting work, the installer registers the acquired token with all
three adapters. Recovery similarly registers the token with the recovery
journal and filesystem before re-inspecting and claiming the operation.
Recovery and installation therefore contend on the same operation lease.

The adapter's token check must be serialized with its mutation. A separate
check followed by an unguarded write reintroduces a race and does not satisfy
the fenced contract.

## Runtime behavior

The installer renews its lease before journal writes, filesystem mutations,
installed-record mutations and while streaming archive chunks. If ownership is
lost, it stops issuing new mutations and leaves the journal for reconciliation
rather than attempting rollback with a stale token. Recovery records its lease
token in the recovery claim and uses the token-bearing staging handle.

Hosts must provide a worker ID unique to each concurrently running worker
instance (stable across that instance's renewals) and configure a lease duration
appropriate to their workload. The runtime does not create background
heartbeat timers; adapters and hosts should keep operations bounded and ensure
renewal occurs during long-running streams.

## Reference implementation and limits

`InMemoryPluginInstallOperationLeaseStore` and
`InMemoryInstalledPluginStore` are single-process reference implementations
for tests and local demonstrations. They are not durable, cross-process or
multi-host coordination services. The runtime does not yet ship a production
SQLite lease/fence store or a production filesystem adapter. The optional
SQLite journal package must be upgraded to implement the fenced journal
contract before it can be used with lease-enabled installation.

This design does not create a distributed transaction across the lease store,
journal, filesystem and installed-record store. Each adapter must persist and
enforce its own highest accepted token. If a side effect may have completed
when an adapter fails, retain the ambiguous journal state for explicit
reconciliation; do not automatically replay it.

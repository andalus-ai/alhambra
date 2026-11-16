# Recovery Archive Format Migrations

## Purpose

Archive format changes must be explicit, inspectable, and host-controlled.
Alhambra does not silently rewrite old records during reads or restore.

The runtime provides:
- a registry of explicit version-to-version migration steps;
- deterministic path selection with ambiguity and cycle rejection;
- a read-only migration planner;
- an executor that writes a migrated copy to a separate destination archive.

The source archive is never modified or purged by migration.

## Registering migrations

Register each supported transition. For example, a host that can migrate
format 2 archives to the current format 1 can register:

```dart
final registry = PluginLifecycleRecoveryJobArchiveMigrationRegistry([
  PluginLifecycleRecoveryJobArchiveFormatMigration(
    fromVersion: 2,
    toVersion: PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
    migrate: (job) => migrateLegacyJobFields(job),
  ),
]);
```

Only one outgoing migration may be registered for a source version. The
registry follows an explicit chain; it does not guess, skip unknown versions,
or select between ambiguous branches. Cycles and missing links produce no
migration path.

Migration callbacks transform the persisted recovery-job value only. They
must be deterministic and must not invoke plugin hooks, access external
resources, or change job identity (job ID, idempotency key, operation ID,
action, creation timestamp, initiator, correlation ID, or ordered plugin IDs).
The executor rejects identity changes and requires the resulting job schema to
match the runtime's current schema.

## Preview and apply

First inspect without mutation:

```dart
final plan = await PluginLifecycleRecoveryJobArchiveMigrationPlanner(
  sourceArchive: sourceArchive,
  registry: registry,
).inspect(jobId: jobId);

if (!plan.canMigrate) {
  // Report plan.disposition; do not attempt an implicit fallback.
}
```

Then explicitly execute the approved plan:

```dart
final executor = PluginLifecycleRecoveryJobArchiveMigrationExecutor(
  sourceArchive: sourceArchive,
  destinationArchive: destinationArchive,
  digestProvider: digestProvider,
  digestAlgorithm: 'SHA-256',
  verifySource: (record) => legacyVerifier.verify(record),
);

final result = await executor.migrate(plan);
```

The host must supply a version-aware source verifier. Legacy archives must not
be migrated merely because their job data can be parsed. The verifier must
validate the source envelope using the algorithm and canonicalization rules
for that source format. The executor fails closed if verification fails.

The executor re-reads and compares the source snapshot against the inspected
plan, verifies that the job is in a safe terminal state with no running steps,
applies the registered migration chain, computes a new digest using the
current snapshot codec, and inserts the new record into the destination
archive. The destination record is read back and compared before success is
reported.

## Outcomes

- `missing`: no source record exists.
- `unsupportedJobSchema`: runtime does not support the job schema.
- `noMigrationPath`: no explicit chain reaches the requested format.
- `alreadyCurrent`: source already uses the requested format; no write is needed.
- `ready`: a migration path is available and the source snapshot is captured.
- `imported`: a new destination copy was written and verified by read-back.
- `alreadyPresent`: an identical destination record already exists.
- `sourceChanged`: source identity did not match the requested job ID.

A conflicting destination record or stale plan throws and requires a new
inspection and host decision. The source archive remains unchanged.

## Operational guarantees and limits

- Migration is copy-to-destination, not in-place mutation.
- The destination adapter must implement atomic `putIfAbsent` by job ID and
  reject conflicting snapshots.
- The executor is not a distributed transaction and does not provide
  cross-process locks or exactly-once behavior.
- The source verifier is host-supplied because legacy format canonicalization
  and digest algorithms are deployment-specific.
- The digest provider is host-supplied; production should use a vetted
  cryptographic implementation and pin the algorithm identifier.
- Migration does not import jobs into the operational recovery-job store,
  execute recovery, resume plugins, or change checkpoints.
- Hosts should preserve the source archive until destination verification,
  backup, audit, and retention requirements are independently satisfied.

## Testing

The runtime tests cover migration path selection, ambiguity/cycle rejection,
unknown versions, read-only preview, stale-plan rejection, source verification,
identity preservation, destination conflicts, and idempotent destination
insertion. These tests being present does not imply they have been executed.

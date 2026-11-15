# Recovery Archive Adapter Conformance

Status: implemented behavioral conformance utility and host adapter contract. No
database-specific recovery archive adapter is bundled by this work.

## Boundary

`alhambra_plugin_runtime` defines the persistence-neutral
`PluginLifecycleRecoveryJobArchive` contract. Applications provide archive
adapters. `alhambra_plugin_test` provides
`PluginRecoveryArchiveConformanceSuite` so adapter authors can exercise the
shared behavioral invariants without adding a storage dependency to the
runtime.

The optional `PluginLifecycleRecoveryJobArchivePurgeStore` contract adds
digest-guarded deletion. It must be implemented atomically by the adapter;
ordinary read-then-delete logic is not sufficient under concurrent writers.

## Running the suite

Add the test package as a development dependency:

```yaml
dev_dependencies:
  alhambra_plugin_test:
    path: ../alhambra_plugin_test
```

Build terminal fixtures with unique job IDs and a distinct snapshot for each
variant:

```dart
final report = await const PluginRecoveryArchiveConformanceSuite().verify(
  archive: archive,
  runId: 'adapter-test-${DateTime.now().microsecondsSinceEpoch}',
  fixtureBuilder: (jobId, variant) => buildTerminalArchiveRecord(
    jobId: jobId,
    marker: 'fixture-$variant',
  ),
);

if (!report.isConformant) {
  throw StateError('Recovery archive adapter failed conformance.');
}
```

The fixture builder must preserve the supplied job ID, produce a valid
terminal recovery job, and change the persisted job snapshot when the variant
changes. The run ID must be unique within the adapter's storage namespace.
The suite writes records and may delete its own purge fixture, so use a
disposable test namespace/database.

## Required behavior covered

| Check | Required behavior |
|---|---|
| Concurrent insert-if-absent | Exactly one writer wins for one job ID |
| Read after insert | Stored job and integrity envelope match the inserted record |
| Identical duplicate | Returns false and preserves the original record |
| Conflicting snapshot | Same job ID with different job content is rejected |
| Wrong-digest delete | Does not delete or alter the archive |
| Matching-digest delete | Deletes only the record whose digest still matches |

The purge checks are skipped when the adapter does not implement the optional
purge-store interface.

## What this suite cannot prove

The concurrent insert check is useful for detecting obvious races, but a
single-process test is not proof of database-level atomicity across independent
connections, isolates, hosts, or regions. Production adapters must add
integration tests using independent connections/workers and verify their
actual uniqueness and transaction guarantees.

The suite does not test:
- crash durability or recovery after process termination;
- cross-region replication or consistency;
- archive backup/restore of the underlying storage service;
- cryptographic strength or key management of the host digest provider;
- legal hold, retention policy, purge authorization, or audit-sink durability;
- exactly-once plugin side effects.

Production digest providers should use a vetted cryptographic hash and pin the
algorithm identifier. Archive stores must implement atomic insert-if-absent by
job ID and reject conflicting snapshots. Purge-capable stores must compare the
stored digest atomically with deletion. Keep operational recovery-job storage
separate from archive-only purge operations.

## Validation status

This document describes the implemented test utility and required host
adapter guarantees. Adding the suite to an adapter's tests does not mean that
adapter has passed it; report the actual test command, database topology, and
results for each implementation.

# Composition Schema Migration and Compatibility

## Schema migrations

`CompositionSnapshotMigrator` applies an explicit sequence of one-version
migrations to declarative snapshot node maps. Migrations are deterministic,
side-effect-free transformations; they must not load plugin code or create
runtime services. Missing migration steps and downgrade requests fail closed.
The source snapshot is not mutated.

The current persisted format remains schema v1. This release introduces the
migration mechanism without inventing a historical v0 format or changing the
current schema. When a future schema change is required, add its migration and
fixtures in the same change that advances `CompositionSnapshotCodec`'s current
schema version.

## Plugin compatibility

`CompositionCompatibilityChecker` compares snapshot node owners with the
plugin IDs discovered by the host. It reports unavailable owners and
contributions, then distinguishes required dependencies (which block restoring
dependent nodes) from optional dependencies (which are warnings).

The checker deliberately does not choose a recovery policy. A host may reject
the plan, defer activation until a plugin is installed, or explicitly degrade
the affected feature. It must not silently delete unavailable contributions
from the persisted source snapshot.

## Version constraints

The current `ExtensionManifest` dependency contract contains plugin IDs only.
It does not express semantic-version ranges. This phase therefore avoids
inventing version semantics; version-range compatibility belongs in a future
manifest-contract revision with a documented range grammar and resolver tests.

# Alhambra Documentation Index

Architecture decisions, public contracts, migration notes and operational guidance
for the Alhambra UI and extension foundation.

Start here:
- [Repository agent instructions](../AGENTS.md)
- [Contributing](../CONTRIBUTING.md)
- [Developer guidelines](DEVELOPER_GUIDELINES.md)
- [Plugin developer guide](PLUGIN_DEVELOPER_GUIDE.md)
- [Repository overview](../README.md)

## Examples
- [Plugin host starter](../examples/plugin_host_starter/README.md) — runnable Flutter host demonstrating plugin activation and contribution registration.
- [Examples index](../examples/README.md) — all maintained examples.

## Architecture and ownership
- [Jezaku host integration contract](JEZAKU_HOST_INTEGRATION_CONTRACT.md) — consumer responsibilities, dependency pinning, backend authority, plugin execution boundary and adoption gates.
- [UI package boundaries](ALHAMBRA_UI_PACKAGE_BOUNDARIES.md) — dependency direction and presentation-only rules.
- [Application host composition](APPLICATION_HOST_COMPOSITION.md) — product ownership, profiles, layout selection and composition roots.
- [Explicit plugin bundle composition](PLUGIN_BUNDLE_COMPOSITION.md) — compiled host-supplied bundles and activation failures.
- [Layout plugin extensibility](LAYOUT_PLUGIN_EXTENSIBILITY.md) — layout extension contracts and compatibility.

## Plugin contracts and lifecycle
- [Plugin developer guide](PLUGIN_DEVELOPER_GUIDE.md) — implement, compose, test and operate a plugin.
- [Plugin test utilities](../packages/alhambra_plugin_test/README.md) — in-process test host and metadata, packaging, discovery and lifecycle conformance checks.
- [Plugin packaging and discovery conformance](PLUGIN_PACKAGING_AND_DISCOVERY_CONFORMANCE.md) — manifest, lockfile, package header and compiled discovery boundaries.
- [Plugin package integrity and trust](PLUGIN_PACKAGE_INTEGRITY_AND_TRUST.md) — payload digest, signature verification adapters, publisher trust and key lifecycle.
- [Plugin capability negotiation](PLUGIN_CAPABILITY_NEGOTIATION.md) — version compatibility and required/optional resolution.
- [Dynamic capability activation](DYNAMIC_CAPABILITY_ACTIVATION.md) — runtime capability activation boundaries.
- [Plugin startup capability gate](PLUGIN_STARTUP_CAPABILITY_GATE.md) — startup preconditions and capability checks.
- [Plugin lifecycle checkpoints](PLUGIN_LIFECYCLE_CHECKPOINTS.md) — lifecycle persistence, reconciliation and explicit recovery.
- [Recovery archive adapter conformance](RECOVERY_ARCHIVE_ADAPTER_CONFORMANCE.md) — behavioral checks and production guarantees for host-provided archive stores.
- [Recovery archive format migrations](RECOVERY_ARCHIVE_FORMAT_MIGRATIONS.md) — explicit version paths, read-only previews, and verified copy migrations.
- [Portable recovery archive packages](RECOVERY_ARCHIVE_PACKAGES.md) — versioned JSON export, integrity verification, import preview, and conflict-safe archive transfer.
- [Capability provider registry](CAPABILITY_PROVIDER_REGISTRY.md) — provider registration and ownership.
- [Capability provider health and revocation](CAPABILITY_PROVIDER_HEALTH_AND_REVOCATION.md) — health signals and dependent capability impact.
- [Governed plugin revocation execution](GOVERNED_PLUGIN_REVOCATION_EXECUTION.md) — approval and execution semantics.
- [Durable plugin revocation recovery](DURABLE_PLUGIN_REVOCATION_RECOVERY.md) — journal, reconciliation and recovery decisions.
- [Transactional revocation audit outbox](TRANSACTIONAL_REVOCATION_AUDIT_OUTBOX.md) — atomic outcome/audit boundary and at-least-once dispatch.
- [PostgreSQL plugin revocation persistence](POSTGRES_PLUGIN_REVOCATION_PERSISTENCE.md) — multi-worker durable journal and SKIP LOCKED outbox claims.
- [Revocation persistence adapter conformance](REVOCATION_PERSISTENCE_ADAPTER_CONFORMANCE.md) — shared behavioral invariants for SQLite and PostgreSQL stores.
- [Revocation operations and inspection](REVOCATION_OPERATIONS_AND_INSPECTION.md) — read-only operational snapshots, metrics and safety boundaries.
- [Scoped revocation replay authorization](SCOPED_REVOCATION_REPLAY_AUTHORIZATION.md) — host identity, scope resolution, replay permission and approval gates.
- [Scoped revocation administrative operations](SCOPED_REVOCATION_ADMIN_OPERATIONS.md) — authorized scoped inspection and access-decision auditing.
- [Revocation scope ownership](REVOCATION_SCOPE_OWNERSHIP.md) — trusted scope assignment, immutable persistence, schema v4 migration and replay isolation.
- [Scoped revocation query architecture](SCOPED_REVOCATION_QUERY_ARCHITECTURE.md) — trusted scope propagation, database-native keyset pagination, snapshot semantics, migrations and retention sequence.
- [Audited dead-letter replay contract](REVOCATION_OPERATIONS_AND_INSPECTION.md#audited-dead-letter-replay-contract) — operator attribution, approval evidence and replay identity rules.

## Composition persistence and compatibility
- [Composition persistence and recovery](COMPOSITION_PERSISTENCE_AND_RECOVERY.md) — persistence boundaries and interrupted composition.
- [Composition schema compatibility](COMPOSITION_SCHEMA_COMPATIBILITY.md) — schema evolution and compatibility policy.

## Documentation conventions

Distinguish implemented behavior from proposals and experimental work. State host
responsibilities, failure semantics, security boundaries and concrete adapter guarantees.
Update this index whenever an architecture or developer document is added.

- [Transactional plugin installation](TRANSACTIONAL_PLUGIN_INSTALLATION.md) — verified package staging, bounded extraction, reversible promotion, journaling and rollback.
- [SQLite plugin installation journal and leases](SQLITE_PLUGIN_INSTALL_JOURNAL.md) — durable operation projection, append-only history, fenced CAS, worker leases and operational limits.
- [SQLite fenced installed-plugin store](SQLITE_INSTALLED_PLUGIN_STORE.md) — durable installed records, create-only writes, compare-and-remove, stable operation ownership and fencing.
- [SQLite plugin installation adapter](../packages/alhambra_plugin_install_sqlite/README.md) — package usage and supported guarantees.
- [Crash-safe local plugin installation filesystem](CRASH_SAFE_PLUGIN_INSTALL_FILESYSTEM.md) — fenced staging, promotion, rollback, ownership evidence and crash-recovery limits.
- [Local plugin installation filesystem package](../packages/alhambra_plugin_install_filesystem/README.md) — adapter usage and operational constraints.

- [Recovery archive package authenticity](RECOVERY_ARCHIVE_PACKAGE_AUTHENTICITY.md) — host-owned detached signatures, trust policy, and authenticated import.
- [Recovery provenance and key governance](RECOVERY_PROVENANCE_AND_KEY_GOVERNANCE.md) — append-only archive operation history, chain verification, and signing-key lifecycle metadata.
- [Recovery provenance production readiness](RECOVERY_PROVENANCE_PRODUCTION_READINESS.md) — adapter conformance, externally signed checkpoints, and production deployment guidance.
- [Recovery provenance operational observability](RECOVERY_PROVENANCE_OPERATIONAL_OBSERVABILITY.md) — read-only timeline queries, chain/anchor/key health summaries, incident classification, and JSON audit exports.

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
- [Audited dead-letter replay contract](REVOCATION_OPERATIONS_AND_INSPECTION.md#audited-dead-letter-replay-contract) — operator attribution, approval evidence and replay identity rules.

## Composition persistence and compatibility
- [Composition persistence and recovery](COMPOSITION_PERSISTENCE_AND_RECOVERY.md) — persistence boundaries and interrupted composition.
- [Composition schema compatibility](COMPOSITION_SCHEMA_COMPATIBILITY.md) — schema evolution and compatibility policy.

## Documentation conventions

Distinguish implemented behavior from proposals and experimental work. State host
responsibilities, failure semantics, security boundaries and concrete adapter guarantees.
Update this index whenever an architecture or developer document is added.

- [Transactional plugin installation](TRANSACTIONAL_PLUGIN_INSTALLATION.md) — verified package staging, bounded extraction, reversible promotion, journaling and rollback.

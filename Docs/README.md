# Alhambra Documentation Index

Architecture decisions, public contracts, migration notes and operational guidance
for the Alhambra UI and extension foundation.

Start here:
- [Repository agent instructions](../AGENTS.md)
- [Contributing](../CONTRIBUTING.md)
- [Developer guidelines](DEVELOPER_GUIDELINES.md)
- [Plugin developer guide](PLUGIN_DEVELOPER_GUIDE.md)
- [Repository overview](../README.md)

## Architecture and ownership
- [UI package boundaries](ALHAMBRA_UI_PACKAGE_BOUNDARIES.md) — dependency direction and presentation-only rules.
- [Application host composition](APPLICATION_HOST_COMPOSITION.md) — product ownership, profiles, layout selection and composition roots.
- [Explicit plugin bundle composition](PLUGIN_BUNDLE_COMPOSITION.md) — compiled host-supplied bundles and activation failures.
- [Layout plugin extensibility](LAYOUT_PLUGIN_EXTENSIBILITY.md) — layout extension contracts and compatibility.

## Plugin contracts and lifecycle
- [Plugin developer guide](PLUGIN_DEVELOPER_GUIDE.md) — implement, compose, test and operate a plugin.
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

## Composition persistence and compatibility
- [Composition persistence and recovery](COMPOSITION_PERSISTENCE_AND_RECOVERY.md) — persistence boundaries and interrupted composition.
- [Composition schema compatibility](COMPOSITION_SCHEMA_COMPATIBILITY.md) — schema evolution and compatibility policy.

## Documentation conventions

Distinguish implemented behavior from proposals and experimental work. State host
responsibilities, failure semantics, security boundaries and concrete adapter guarantees.
Update this index whenever an architecture or developer document is added.

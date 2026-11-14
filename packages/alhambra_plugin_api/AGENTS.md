# Instructions for alhambra_plugin_api

This package owns stable, framework-neutral contracts consumed by Alhambra hosts,
plugins and runtime implementations.

## Ownership
- Define interfaces, immutable models, identifiers, DTOs and semantic contracts.
- Do not implement host orchestration, plugin discovery, persistence drivers or UI runtime behavior here.
- Do not import alhambra_plugin_runtime, alhambra_sdk, downstream products or infrastructure vendors.
- Keep Flutter dependencies out of a new contract unless a Flutter type is essential to the public API.

## API design
- Prefer immutable values, explicit nullability and stable identifiers.
- Document lifecycle, ordering, error, cancellation, idempotency and compatibility semantics.
- Treat constructors, exports, enum values and serialized field names as public API.
- Avoid exposing implementation-specific classes or leaking persistence/transport models.
- Capability declarations describe compatibility/requirements; they do not grant authorization.

## Validation
- Add focused contract tests for invariants and serialization where applicable.
- Verify the public barrel export and package dependency graph.
- Run formatter, analyzer and package tests; report commands that were not run.
- Update the package README and relevant Docs pages when contracts change.

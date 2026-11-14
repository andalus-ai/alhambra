# Agent and Contributor Instructions

These instructions apply to the entire Alhambra repository. More specific AGENTS.md
files may refine them but must not weaken the architecture and security rules here.

## Project identity

Alhambra is a neutral, reusable Flutter UI and extension foundation. It owns
presentation primitives, design tokens, responsive layouts, generic host
composition contracts, plugin APIs/runtime, and optional infrastructure adapters.
It is not the agent runtime or a product-specific application.

Ownership:
- Alhambra: reusable UI, extension contracts, plugin lifecycle and presentation infrastructure.
- Andalus: agent runtime, orchestration, execution, policy and backend capabilities.
- Wayang: low-code/workflow authoring semantics and product-specific studio/console composition.
- Cifr UI: coding-agent workspace, editor, diff, terminal, chat and coding-specific flows.

Dependency direction is from product applications into Alhambra. Alhambra MUST NOT
import, name, or infer behavior from downstream products. Do not add product-specific
routes, screens, domain aggregates, services, or default plugin bundles to neutral packages.

## Repository map

| Path | Responsibility |
|---|---|
| packages/alhambra_core | UI-independent primitives and neutral types |
| packages/alhambra_ui | Design system, widgets, responsive layouts and shells |
| packages/alhambra_plugin_api | Stable plugin and extension contracts |
| packages/alhambra_plugin_runtime | Registration, lifecycle, composition and recovery |
| packages/alhambra_sdk | Extension-author API |
| packages/alhambra_identity | Optional identity integration |
| packages/alhambra_workspace | Optional generic workspace services |
| packages/alhambra_services | Optional application services |
| packages/alhambra_data* | Optional persistence adapters |
| packages/alhambra_network* | Optional networking adapters |
| packages/alhambra_intelligence | Optional intelligence integrations |
| alhambra/ | Transitional standalone host, not the public package boundary |
| Docs/ | Architecture, contracts, operations and migration guidance |

Before editing, inspect the target package's pubspec.yaml, README, public exports,
neighboring implementation and tests. Do not assume a directory name proves current status.

## Architecture rules

### Dependency inversion and optionality
- Keep alhambra_core small and independent of Flutter where practical.
- Keep alhambra_ui presentation-only. It MUST NOT require identity, workspace
  persistence, search, networking, analytics, AI, or a service locator merely to render.
- Put contracts at neutral boundaries and concrete adapters in optional packages
  or the owning application.
- Avoid foundational dependencies when an injected interface, DTO or callback suffices.
- Keep package dependencies acyclic.

### Host composition
- The deployable application is the composition root.
- Register only compiled plugin/layout contributions the host intends to ship.
- Keep product plugin bundles out of generic Alhambra loaders.
- Runtime plugin registration selects compiled implementations; it is NOT a mechanism
  for downloading and executing arbitrary Dart code.
- Layout capabilities express compatibility, not authorization, licensing or security.
- Preserve explicit user choices while compatible; use deterministic fallback behavior.

### Public API stability
- Treat exports, constructors, enum values, serialized fields, callbacks and lifecycle
  semantics as public API.
- Prefer additive, source-compatible changes. Document migration for breaking changes.
- Keep transport DTOs, persistence entities and product domain aggregates out of shared UI APIs.
- Do not silently change defaults, ordering, retry behavior or failure semantics.

## Plugin lifecycle, capability and recovery safety

Plugin code may perform side effects. Changes in this area require explicit failure analysis.

- Validate plugin IDs, capability IDs, versions, dependencies and lifecycle preconditions.
- Capability negotiation is not authorization. A declaration is not a permission grant.
- Do not invoke plugin code during discovery, negotiation, planning or read-only reconciliation.
- Recovery planning MUST be read-only. Recovery execution requires an explicit host decision.
- Never automatically retry an ambiguous side effect merely because a checkpoint or journal
  says starting, stopping, pending or failed. Inspect authoritative runtime and external state.
- Use stable operation and idempotency identifiers. A new attempt needs a new operation identity
  and fresh approval where applicable.
- In-memory stores are test/reference implementations only. Do not claim crash durability,
  cross-process safety or exactly-once effects unless the concrete adapter guarantees them.
- Durable stores must document atomicity, uniqueness, concurrency, ordering, retention and recovery.
- Outbox delivery is at-least-once unless a stronger end-to-end protocol is proven. Consumers
  deduplicate using stable event IDs.
- Fence leased worker acknowledgements with unique lease tokens and reject stale tokens.
- Never persist credentials, tokens, arbitrary plugin payloads, raw exception messages or secrets
  in checkpoints, journals, audit events or diagnostics. Use sanitized summaries and stable codes.

## Dart and Flutter conventions

- Follow dart format and the package's lint configuration.
- Prefer sound null safety, immutable value objects, final fields and explicit interfaces.
- Use descriptive names and small methods with clear side-effect boundaries.
- Keep widget build methods declarative; put orchestration and persistence in controllers/services.
- Inject clocks, ID factories, stores, publishers and external services for deterministic tests.
- Avoid global mutable state, hidden service locators and speculative abstractions.
- Keep comments focused on invariants, safety constraints and non-obvious decisions.

## Testing requirements

Tests verify behavior and contracts, not merely implementation details.

- UI: rendering, constraints, accessibility labels, empty/loading/error states and callbacks.
- Layouts: required/preferred capabilities, deterministic ranking and no-compatible-layout behavior.
- Plugin loading: independent failures, rollback, structured reporting and no product registration.
- Lifecycle: success, failure, partial side effects, compensation, checkpoint write failure and stale requests.
- Negotiation: version compatibility, required/optional requirements and deterministic provider selection.
- Persistence: duplicate IDs, revision conflicts, stale writes and concurrent workers.
- Outbox: atomic completion/enqueue, duplicate events, lease expiry/reclaim, stale-token rejection,
  bounded attempts, dead letters and publish-success/ack-failure redelivery.

Use fake clocks and deterministic IDs instead of sleeps. Do not use real network services in unit tests.
In-memory fakes cannot prove database transaction or cross-process locking semantics; add adapter
integration tests for those guarantees.

## Validation workflow

Run checks from the package being changed. Inspect its SDK constraints and path dependencies;
do not assume the repository root is a Dart workspace.

~~~
cd packages/<package>
dart format --output=none --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
~~~

Use dart test for pure Dart packages that do not depend on Flutter. For UI changes, run widget tests.
For host changes, validate the complete host workspace and relevant target platform. If a command
cannot run, report the exact limitation. Never claim tests, analysis, builds or CI passed unless
they were actually run and observed.

Before opening a PR:
1. Review the full diff for generated noise and unrelated changes.
2. Verify public exports and package dependency direction.
3. Run formatter, analyzer and targeted tests.
4. Update docs/changelog when public behavior changes.
5. State unrun checks and known limitations clearly.

## Documentation requirements

Distinguish implemented and tested behavior, implemented but unvalidated behavior, proposed work,
and deprecated behavior. For each public contract explain purpose, ownership, inputs/outputs,
lifecycle, failure modes, compatibility and security considerations.

Avoid claims such as durable, atomic, exactly once, secure or production ready without stating
the concrete conditions and adapter guarantees. Use relative links and update the Docs index.

## Pull request expectations

A PR should include problem/motivation, scope/non-goals, architecture/API decisions, compatibility
and migration impact, failure/recovery/security considerations, exact validation results,
documentation updates and intentionally deferred work. Keep unrelated refactors separate.

## Agent operating rules

1. Inspect current branch and latest target branch before editing.
2. Read this file and target-package guidance.
3. Trace public contracts and call sites before changing an API.
4. Prefer a complete vertical slice over speculative rewrites.
5. Never invent test output, CI status, file contents, branch state or PR state.
6. Treat .env as sensitive; use .env.example for placeholders and variable names.
7. Never add secrets, credentials, private keys or production data to source, fixtures, logs or docs.
8. Keep the user informed of branch, files changed, PR link and validation status.

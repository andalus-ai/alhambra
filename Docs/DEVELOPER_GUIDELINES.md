# Developer Guidelines

This guide complements the repository-wide [AGENTS.md](../AGENTS.md) and
[Contributing Guide](../CONTRIBUTING.md).

## 1. Choose the correct package

- Shared visual behavior and layout primitives: alhambra_ui.
- Flutter-independent value types and utilities: alhambra_core.
- Plugin interfaces and stable extension DTOs: alhambra_plugin_api.
- Registration, lifecycle, composition and recovery: alhambra_plugin_runtime.
- Extension-author convenience APIs: alhambra_sdk.
- Concrete storage/network/identity integration: optional adapter package.
- Product workflow, coding-agent or agent-runtime behavior: owning product, not Alhambra.

If a widget needs product data, define a presentation DTO/callback and map product domain types
in the host. Do not import product repositories into widgets.

## 2. Package dependency policy

Use the narrowest dependency that solves the problem. A new dependency proposal must explain
why a neutral interface is insufficient, package ownership, runtime/dev-only status, impact on
platform support and binary size, and replacement/testing strategy.

Keep package dependency direction acyclic and product-agnostic.

## 3. Public API design

- Prefer immutable input/output models.
- Use stable identifiers and explicitly versioned serialized contracts across persistence/process boundaries.
- Make required and optional capability semantics explicit.
- Return structured outcomes for expected failures; reserve exceptions for exceptional conditions.
- Document whether operations are asynchronous, idempotent, cancellable and retryable.
- Avoid exposing implementation classes when a stable interface is sufficient.

## 4. UI implementation

- Build from constraints and capabilities, not device-name or product assumptions.
- Keep widgets focused on presentation and user interaction.
- Inject asynchronous work as callbacks or controllers.
- Provide loading, empty, error and disabled states.
- Consider semantics, keyboard/focus behavior and touch targets.
- Never embed authorization decisions in visibility or layout logic.
- Test narrow/wide constraints and state transitions.

## 5. Plugin runtime implementation

Treat activation and deactivation as side-effecting operations. A lifecycle change must specify:
1. Preconditions and dependency ordering.
2. Exact side-effect boundary.
3. State/checkpoint writes before and after the side effect.
4. Rollback/compensation behavior.
5. What can be inferred after a crash.
6. What the host must inspect.
7. Whether retry is safe and which idempotency key governs it.

Recovery planning is read-only. Recovery execution requires an explicit host decision and must
reject stale operation/sequence data. An inactive registry entry does not prove external cleanup.

## 6. Persistence, audit and outbox

Persistence-neutral interfaces belong in runtime/API only when multiple adapters or hosts need them.
Concrete database drivers belong in optional adapter packages.

A production adapter must document transaction boundary/isolation, uniqueness and idempotency,
conditional update/CAS, multi-process locking, crash behavior, schema migration, retention,
backup/restore and operational recovery.

For outbox dispatch, assume at-least-once delivery. Use stable event IDs, consumer deduplication,
lease-token fencing, bounded retries and dead-letter observability. A successful publish followed
by a worker crash before acknowledgement can cause redelivery; this is expected.

Never put credentials, raw plugin data or unfiltered exception messages in audit records. Use
allow-listed fields and stable error codes.

## 7. Test strategy

Prefer a pyramid:
1. Unit tests for deterministic domain and contract behavior.
2. Package tests for component integration.
3. Adapter integration tests against the real database/transport.
4. Host smoke/build checks for actual embedding behavior.

Use fake clocks, deterministic IDs and controllable failure injection. For concurrency, test
interleavings and stale tokens rather than timing-sensitive sleeps. In-memory fakes cannot prove
database transaction or cross-process locking semantics.

## 8. Commands and validation

Run commands inside the package being changed:

~~~
dart format --output=none --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
~~~

For pure Dart packages, use dart test when Flutter is not a dependency. Inspect SDK constraints
first. Run host-level checks when changing app composition or platform integrations.

Report actual outcomes:
- **Passed:** command executed and returned success.
- **Failed:** command executed and returned errors.
- **Not run:** command was not executed, with reason.
- **Blocked:** command could not run because of a named environment/dependency issue.

Do not say validated or tests passed if tests were only authored.

## 9. Documentation style

Use normative language consistently:
- **MUST** for invariants required for correctness or safety.
- **SHOULD** for strong defaults with justified exceptions.
- **MAY** for optional behavior.

Every architecture document should state status (implemented, proposed, experimental or deprecated),
scope, ownership and relevant host responsibilities. Examples should compile against current APIs;
label pseudocode. Explain failure semantics and adapter guarantees.

Update [Docs/README.md](README.md) when adding or materially changing a document.

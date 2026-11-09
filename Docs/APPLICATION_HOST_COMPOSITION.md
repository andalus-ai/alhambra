# Application Host Composition Contract

This document defines how a product application composes Alhambra without
turning the foundation into a product-specific application.

## 1. Ownership and dependency direction

Alhambra is a presentation and extension foundation. It owns reusable UI
primitives, responsive layout contracts, design tokens, shell composition, and
the APIs required to contribute compiled UI features.

Product repositories own their own domain behavior and product-specific
presentation:

| Product | Owns |
|---|---|
| Cifr UI | Coding-agent workspace, editor, diff, terminal, chat, run/debug and coding-agent navigation |
| Wayang | Workflow authoring, visual automation, workflow-specific studio and console composition |
| Andalus | Agent runtime, execution, orchestration, policy and backend capabilities |
| Alhambra | Reusable Flutter UI, generic layout selection, design system and extension contracts |

The dependency direction is downstream-to-foundation:

`product application -> Alhambra public packages`

Alhambra packages must not import product repositories or infer product
identity from package names, routes, feature IDs, or workspace state.

## 2. Host bootstrap is the composition root

Each deployable Flutter application owns one composition root. The root is
responsible for:

1. Providing an `ApplicationProfile` for the host.
2. Registering only the compiled layout contributions it uses.
3. Registering only the compiled feature/plugin bundles it uses.
4. Supplying product-owned services and callbacks through public interfaces.
5. Choosing the initial layout and navigation composition.
6. Wiring persistence, identity, networking and telemetry adapters when
   required by that application.

Do not move these decisions into a universal Alhambra default. A consumer
should be able to adopt the design system and layout API without adopting
Alhambra's standalone application, identity provider, workspace persistence,
or optional service integrations.

## 3. Application profile contract

The host supplies an immutable `ApplicationProfile`. Its application ID is
owned by the host, not by Alhambra. Capabilities describe UI affordances that
the host can actually provide; layout hints express preferences only.

Use stable, namespaced capability identifiers. Recommended conventions:

- `ui.shell`, `ui.navigation`, `ui.responsive`: generic UI capabilities.
- `data.tables`, `data.visualization`: generic presentation capabilities.
- `com.example.product.workflow-canvas`: product-owned capability.
- `com.example.extension.timeline-panel`: extension-owned capability.

Do not encode authorization, tenant access, feature licensing, or security
policy as layout capabilities. A layout requirement is a compatibility
predicate, not an access-control decision. Authorization must be enforced by
the application/service boundary that owns the protected operation.

A layout should declare the minimum required capabilities and optional
preference hints. Missing required capabilities make it incompatible;
missing preferred hints only reduce its ranking. Avoid broad requirements
that make a layout appear compatible with a host that cannot supply its
actual slots or interactions.

## 4. Layout registration and selection

The application composition root registers its layout implementations
explicitly. Alhambra's generic package must not import every downstream
layout to make them globally available.

The host should:

- preserve a user's explicit layout choice while it remains compatible;
- otherwise rank compatible layouts by declared preference hints;
- use a deterministic tie-breaker;
- show a useful configuration error if no registered layout is compatible;
- avoid silently falling back to a product-specific layout.

New layouts should implement `ProfileAwareLayoutPlugin`. The legacy
`AppKind` build method exists only as a migration path for existing
implementations. New product integrations must not add product categories to
`AppKind`.

## 5. Plugin bundles are compiled composition

Flutter feature contributions are compiled into the application. Each product
imports its own bundle and registers only the implementations it needs.
This makes dependency ownership explicit and allows the compiler to remove
unused code.

A runtime plugin registry may select among compiled contributions and manage
their lifecycle. It must not be described as a mechanism for downloading and
executing arbitrary Dart code.

Remote or marketplace-delivered features need a separately designed,
platform-supported delivery model. Until such a model exists, marketplace
metadata may describe available features, but executable widgets must be
present in the host binary.

Plugin activation failures should be observable. One failing optional
contribution should not prevent independent contributions from activating,
but the host must receive a structured failure report and decide whether the
application can continue.

## 6. Service and data boundaries

Reusable widgets should receive view data and callbacks. They should not
instantiate product repositories, issue direct HTTP requests, read product
databases, or depend on a particular identity SDK.

Prefer this flow:

`product adapter -> presentation DTO/callback -> Alhambra widget`

Keep transport DTOs, persistence entities, and domain aggregates outside the
shared UI API. Convert them in the product adapter. If multiple products need
a genuinely common service abstraction, place the contract in a neutral
package and keep concrete adapters in their owning products.

Optional Alhambra integrations must remain optional package dependencies.
The base UI package should not require identity, workspace persistence,
search, analytics, AI, or networking merely to render a shell.

## 7. Migration and compatibility policy

The standalone `alhambra/` application is a transitional adopter of the
shared packages. Its legacy feature wiring is not a specification for the
foundation API.

Migrate product workflows in this order:

1. Identify the product-owned workflow and its required UI capabilities.
2. Move or implement its domain models and orchestration in the owning
   product repository.
3. Implement product-owned layout/feature contributions against Alhambra's
   public contracts.
4. Compose those contributions in that product's application root.
5. Verify parity for critical user journeys and persistence behavior.
6. Only then remove the corresponding transitional host implementation.

Do not delete a legacy workflow solely because a generic foundation package
no longer imports it. Keep compatibility adapters during migration and mark
them deprecated only when a replacement is available.

## 8. Pull-request acceptance checklist

- [ ] No Alhambra package imports Cifr UI, Wayang, or Andalus product code.
- [ ] Product-specific routes, domain models and workflows remain product-owned.
- [ ] The application composition root supplies its profile and compiled
      contribution bundles.
- [ ] New layouts use open profile requirements, not new `AppKind` values.
- [ ] Capability requirements describe UI compatibility, not authorization.
- [ ] Optional integrations are not mandatory dependencies of the base UI.
- [ ] Runtime plugin behavior does not claim arbitrary Dart code execution.
- [ ] Activation and layout-selection failures are observable and actionable.
- [ ] Legacy workflows are retained until product parity is verified.
- [ ] Package tests, analyzer, and relevant application tests run in CI.

# Alhambra — Neutral Flutter UI and Extension Foundation

Alhambra is a reusable, application-agnostic UI foundation for building
responsive Flutter applications with shared design primitives, adaptive
layouts, plugin contributions, and declarative UI surfaces.

It is intended to support multiple products rather than define one product's
workflow. Examples include Wayang's low-code studio and console, operational
admin applications, analytics dashboards, and other Flutter applications.

**Alhambra is not the coding-agent product.** The coding-agent experience and
its product-specific composition belong in
[ Cifr UI ](https://github.com/andalus-ai/cifr-ui).

## Repository structure

| Path | Responsibility |
|---|---|
| `packages/alhambra_core` | Small, UI-independent foundation types and utilities |
| `packages/alhambra_ui` | Design tokens, reusable widgets, responsive layouts, shells, and UI presentation models |
| `packages/alhambra_plugin_api` | Stable contracts for application and UI contributions |
| `packages/alhambra_plugin_runtime` | Plugin lifecycle, registries, composition, and runtime services |
| `packages/alhambra_sdk` | Developer-facing SDK for Alhambra extensions |
| `packages/alhambra_identity` | Optional identity integration |
| `packages/alhambra_workspace` | Optional generic workspace domain services |
| `packages/alhambra_services` | Optional application services |
| `packages/alhambra_data*` | Optional persistence adapters |
| `packages/alhambra_network*` | Optional networking adapters |
| `packages/alhambra_intelligence` | Optional AI/intelligence integration |
| `alhambra/` | Transitional standalone host application; not the reusable package boundary |

Optional packages are composed by adopters as needed. The base UI package
should not force consumers to adopt Alhambra identity, workspace persistence,
search services, or intelligence integrations.

## Product ownership

- **Alhambra** owns neutral presentation infrastructure and extension
  contracts.
- **Cifr UI** owns coding-agent screens, editor workflows, agent execution
  presentation, and coding-specific workspace models.
- **Wayang** owns low-code/workflow authoring semantics and product-specific
  studio/console composition.
- **Andalus** owns agent runtime and backend execution capabilities.

Product-specific packages may depend on Alhambra's public contracts. Alhambra
must not depend on Cifr UI, Wayang, or another downstream product.

## Architecture principles

### 1. Presentation does not own application services

Reusable widgets accept application-provided data and callbacks. Search
widgets, for example, use UI-facing result DTOs and an injected search handler
rather than requiring a particular search backend.

Workspace presentation uses opaque identifiers and presentation lifecycle
labels. Applications map their own domain state into these UI models.

### 2. Open application profiles

Hosts describe their identity, capabilities, and layout preferences through
`ApplicationProfile`. Layout requirements distinguish hard capability
constraints from advisory preference hints. New integrations should not add
product names to a closed application-kind enum.

### 3. Explicit plugin composition

The plugin API and runtime do not select a universal product feature set.
Each deployable application imports and supplies its own compiled plugin
bundle. This allows Flutter's tree shaker to omit unused implementations.

This is compile-time composition; it does not imply arbitrary downloaded Dart
code can be executed dynamically.

### 4. Responsive behavior follows constraints

Layouts respond to available width and host capabilities rather than assuming
that a device category always determines the UI. Layouts are opt-in
contributions and can be selected by application profile.

## Current migration status

The reusable package boundaries are being separated from the transitional
standalone host application in stages.

- The generic layout host no longer registers coding-agent layout
  contributions by default.
- Capability-aware layout metadata and selection are in place.
- The UI package is being decoupled from mandatory identity, workspace, and
  service dependencies.
- The old unused coding-agent layout implementation is being removed from
  this repository.
- The standalone `alhambra/` host still contains legacy application wiring.
  It will be simplified or retired only after the corresponding Cifr UI
  workflows are verified; it is not the definition of Alhambra's public
  foundation API.

See [`Docs/`](Docs/) for extension contracts, package boundaries, and
migration decisions.

## Development

This repository contains multiple Dart/Flutter packages. Work from the
package directory being changed and resolve its local path dependencies in the
expected workspace layout.

Typical package checks:

```bash
cd packages/alhambra_core
dart test

cd ../alhambra_plugin_api
flutter test

cd ../alhambra_plugin_runtime
flutter test

cd ../alhambra_ui
flutter test
```

The transitional app may have additional workspace/path dependencies. Do not
treat a successful package test as proof that every standalone app target is
buildable; run the app's analyzer and target-platform build in its complete
workspace before release.

## License

Apache License 2.0.

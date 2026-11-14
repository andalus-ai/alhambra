# Contributing to Alhambra

Thank you for helping improve Alhambra. Contributions should strengthen reusable
contracts without pulling downstream product behavior into the foundation.

## Before you start

1. Read [AGENTS.md](AGENTS.md) for architecture, coding, testing and security rules.
2. Read the relevant package README and applicable [architecture documents](Docs/README.md).
3. Search for existing contracts and implementations before introducing a parallel abstraction.
4. For large API/architecture changes, describe the proposal and migration impact before implementation.

## Development setup

This repository contains multiple packages and a transitional standalone host. It is not
necessarily a single root-level Dart workspace.

- Use Dart/Flutter SDK versions declared by the package.
- Run pub get from that package directory.
- Resolve local path dependencies in the expected workspace layout.
- Do not commit generated build output, IDE state, secrets or machine-specific configuration.

## Change process

1. **Define ownership.** Confirm the behavior belongs in Alhambra rather than Andalus, Wayang,
   Cifr UI or another product.
2. **Choose the layer.** Put neutral contracts in core/API packages, concrete infrastructure in
   optional adapters, and product behavior in the host application.
3. **Preserve compatibility.** Prefer additive changes. Document migrations for breaking changes.
4. **Test failure paths.** Especially for lifecycle, persistence, recovery, audit and concurrency.
5. **Update documentation.** Public contracts need examples, limitations and operational semantics.
6. **Review the diff.** Remove unrelated formatting, generated files and accidental config changes.

## Validation

Run applicable checks from the package directory:

~~~
dart format --output=none --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
~~~

For pure Dart packages, use dart test when appropriate. For host changes, also run host-level
analysis and relevant target builds. Report commands not run and why.

## Pull request template

### Summary
What problem does this change solve?

### Design and boundaries
Which package owns the behavior? What alternatives were considered?

### Compatibility
Does this alter public APIs, serialized data, defaults or lifecycle semantics? What migration is needed?

### Safety and failure behavior
What happens on partial failure, interruption, duplicate execution, stale state or invalid input?

### Validation
List exact commands and observed results. Clearly mark checks not run.

### Documentation
List updated architecture, API, developer or operational documents.

## Security

Never commit secrets or real user/tenant data. Sanitize audit and diagnostic payloads. Do not treat
capability declarations as authorization. Do not add automatic retries for ambiguous side effects
without explicit idempotency, approval and recovery semantics.

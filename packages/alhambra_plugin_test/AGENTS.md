# Instructions for alhambra_plugin_test

This package provides test-only utilities for Alhambra plugin authors.

## Boundaries
- Keep this package suitable for dev_dependencies; never add it as a runtime
  dependency of production packages.
- Exercise the real public plugin API and runtime rather than reimplementing
  lifecycle semantics in mocks.
- Keep helpers generic and product-neutral.
- Do not imply that in-process tests provide code sandboxing or process isolation.

## API design
- Prefer small helpers that expose the underlying runtime for precise tests.
- Keep snapshots immutable and clearly describe whether counts are aggregate or
  owner-specific.
- Do not silently swallow activation, deactivation, or cleanup failures.
- Avoid importing flutter_test from the package's public library.

## Validation
- Test successful activation/deactivation, partial activation failure, failed
  deactivation cleanup, and host close behavior.
- Keep fixtures deterministic and avoid network, clock, or filesystem dependencies.
- Update the package README and central documentation index when public helpers change.

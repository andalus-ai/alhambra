# Instructions for alhambra_plugin_test

- Keep this package suitable for dev_dependencies, never a production runtime dependency.
- Exercise the real public plugin API and runtime rather than reimplementing lifecycle semantics in mocks.
- Keep helpers generic and product-neutral.
- Metadata checks must be side-effect free.
- Lifecycle execution must be explicitly opt-in and documented as executing trusted plugin code.
- Keep results immutable and machine-readable with stable issue codes.
- Do not silently swallow lifecycle or cleanup failures.
- Do not impose version or capability semantics absent from the public API.
- Cover valid/invalid metadata, duplicate plugin IDs, lifecycle success, activation failure and deactivation failure.
- Update package docs and the central documentation index when public helpers change.

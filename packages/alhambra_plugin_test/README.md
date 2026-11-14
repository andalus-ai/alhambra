# Alhambra Plugin Test Utilities

A test-only support package for exercising plugins through the real Alhambra
PluginManager and ExtensionRuntime.

## Add the package

~~~yaml
dev_dependencies:
  alhambra_plugin_test:
    path: ../alhambra_plugin_test
~~~

## Metadata and plugin-set conformance

Use `PluginConformanceSuite` for side-effect-free checks before handing a
plugin selection to the host:

~~~dart
const conformance = PluginConformanceSuite();
conformance.validateMetadata(plugin.metadata).throwIfNotConformant();
conformance.validatePluginSet(selectedPlugins.map((p) => p.metadata))
    .throwIfNotConformant();
~~~

Checks require non-empty, trimmed plugin IDs, names, versions and capability
IDs, and reject duplicate capability IDs within one plugin or duplicate
plugin IDs in a selected set. They deliberately do not impose a SemVer grammar
on `PluginMetadata.version`; the public contract defines it as a string without
a formal version parser.

## Opt-in lifecycle round trip

For trusted plugin implementations:

~~~dart
final result = await const PluginConformanceSuite().verifyLifecycle(plugin);
result.throwIfNotConformant();
~~~

This executes plugin code in a fresh in-process manager and verifies that
manager active state and aggregate contribution counts return to baseline.
It is not a sandbox and cannot prove external resources or side effects were
released.

## Capability compatibility

The runtime's `PluginCapabilityNegotiator` remains authoritative: major
versions must match and provider minor versions must meet the requested
minimum; patch versions do not affect compatibility. Missing or incompatible
required capabilities block activation; optional requirements produce a
degraded result. Negotiation does not grant permissions.

Lifecycle conformance does not imply process isolation, durable crash recovery,
or exactly-once external effects.

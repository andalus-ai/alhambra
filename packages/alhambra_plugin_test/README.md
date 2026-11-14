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

## Package and discovery conformance

Use `PluginPackagingConformanceSuite` to validate the richer package manifest,
lockfile and package-header contracts, and to exercise the actual legacy
compiled-plugin discovery graph:

```dart
const suite = PluginPackagingConformanceSuite();
suite.validatePackageManifest(package.manifest).throwIfNotConformant();
suite.validatePackageMetadata(package.manifest, package.metadata)
    .throwIfNotConformant();
suite.validateLockfile(lockfile).throwIfNotConformant();
suite.validateDiscoveryGraph(discovered.map((item) => item.manifest))
    .throwIfNotConformant();
```

The suite checks manifest identity and version fields, host API bounds,
duplicate/self dependencies, capability and platform declarations, lockfile
key/ID consistency, and package header consistency. Discovery validation
delegates to `PluginDependencyResolver.resolve`, covering the current
required-ID-only dependency graph. It does not implement resolution of the
richer version-constrained package dependency model.

See [Plugin packaging and discovery conformance](../../Docs/PLUGIN_PACKAGING_AND_DISCOVERY_CONFORMANCE.md)
for the current loader, verifier and trust boundaries.

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

## Lower-level lifecycle assertions

Use `AlhambraPluginTestHost` when a test needs precise control over activation
order, failure injection, or registry assertions:

~~~dart
final host = AlhambraPluginTestHost();
final before = host.snapshot();

await host.activate(MyPlugin());
expect(host.isActive('my.plugin'), isTrue);
expect(host.snapshot().differenceFrom(before)['commands'], 1);

await host.deactivate('my.plugin');
expect(host.snapshot().hasSameCountsAs(before), isTrue);
~~~

`PluginContributionSnapshot` captures aggregate registry counts; it does not
claim that a contribution belongs to a particular plugin. Use stable
contribution IDs and the runtime's owner-scoped cleanup behavior for
ownership assertions.

## Capability compatibility

The runtime's `PluginCapabilityNegotiator` remains authoritative: major
versions must match and provider minor versions must meet the requested
minimum; patch versions do not affect compatibility. Missing or incompatible
required capabilities block activation; optional requirements produce a
degraded result. Negotiation does not grant permissions.

## Scope and limitations

- This package is intended for `dev_dependencies`, not production runtime use.
- It exercises in-process lifecycle behavior and does not isolate plugin code.
- Lifecycle checks cannot prove external side effects were released.
- It does not simulate process crashes, durable storage, cross-process races,
  or external side-effect recovery.
- It does not provide exactly-once execution guarantees.

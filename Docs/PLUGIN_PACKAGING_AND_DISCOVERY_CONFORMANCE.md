# Plugin Packaging and Discovery Conformance

Alhambra currently exposes two distinct plugin description layers:

- `PluginPackageManifest` is the richer package/install contract. It includes semantic versions, host API bounds, required and optional version-constrained dependencies, capability requests, edition/platform constraints and source metadata.
- `ExtensionManifest` is the compiled-host discovery contract used by `PluginLoader`. Its dependency list is a list of required plugin IDs. Discovery reads `plugin.json` from configured directories, but does not execute code or dynamically load arbitrary Dart code.

Use `PluginPackagingConformanceSuite` from the test-only `alhambra_plugin_test` package to validate package declarations before handing them to a host:

```dart
const suite = PluginPackagingConformanceSuite();

suite.validatePackageManifest(package.manifest).throwIfNotConformant();
suite
    .validatePackageMetadata(package.manifest, package.metadata)
    .throwIfNotConformant();
suite.validateLockfile(lockfile).throwIfNotConformant();
```

The suite checks required text fields, non-negative semantic-version components, host API bounds, duplicate/self dependencies, duplicate capability requests, platform declarations, lockfile key/ID consistency and package header/manifest consistency.

For the existing compiled-plugin discovery graph:

```dart
suite.validateDiscoveryGraph(discovered.map((item) => item.manifest))
    .throwIfNotConformant();
```

This delegates to the actual `PluginLoader.resolveDependencyOrder` contract and reports missing required dependencies, duplicate IDs, invalid IDs and cycles. The resolver preserves discovery order where no dependency edge constrains ordering and returns a dependency-first plan.

## Security and compatibility boundaries

- These checks validate declarations; they do not authenticate publishers or verify cryptographic signatures.
- The current `DefaultPluginPackageVerifier` checks package format policy, publisher block policy and signing-key presence. It does not perform cryptographic signature verification or recompute the declared payload content hash. Do not treat its current result as proof of cryptographic integrity.
- The current discovery loader parses local manifest files and returns directories. It does not dynamically execute code; the host constructs trusted compiled plugin instances.
- `ExtensionManifest.dependencies` has no version or optional-dependency semantics. Do not silently infer those semantics from `PluginPackageManifest`.
- `PluginPackageManifest` and `PluginLockfile` are declaration models; this conformance suite does not implement a resolver for the richer version-constrained graph or install transaction.
- A lockfile integrity hash is checked for presence/whitespace only. The hash algorithm and payload canonicalization are not defined by this contract.
- The suite is test/development support, not a production security gate or sandbox.

# Plugin Developer Guide

This guide describes the current Alhambra plugin API and host runtime. It is an
extension-author guide, not a promise of dynamic code loading or sandboxing.

## 1. Understand the trust and composition model

An Alhambra plugin is a Dart implementation of `AlhambraPlugin`. The application
host constructs and selects plugin instances and passes those instances to
`PluginManager`. The runtime manages their lifecycle and contribution cleanup.

Plugins are compiled into the application or otherwise supplied as trusted
code by the host. Runtime registration is not a mechanism for downloading and
executing arbitrary Dart code, and the runtime does not provide an isolation
sandbox.

Keep product-specific behavior in the host product. A plugin should depend on
the narrow public API it needs and should not depend on unrelated application
internals.

## 2. Package selection

- `alhambra_plugin_api`: contracts and contribution models.
- `alhambra_plugin_runtime`: host-side plugin manager and registries.
- `alhambra_sdk`: convenience facade re-exporting the public plugin API.
- Optional adapter packages: concrete storage, networking or identity integrations.

For a plugin library, depend on `alhambra_sdk` or `alhambra_plugin_api` when
only contracts are needed. The host application owns and depends on the runtime.

## 3. Implement a minimal plugin

The following is the smallest lifecycle implementation. It deliberately does
not register UI contributions, so it can be used as a starting point.

```dart
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

final class GreetingPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'example.greeting',
        name: 'Greeting',
        version: '1.0.0',
        description: 'A minimal Alhambra plugin example.',
      );

  @override
  Future<void> activate(PluginContext context) async {
    // Register supported contributions through context here.
    // Keep activation bounded and release partially acquired resources on failure.
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    // Release plugin-owned resources. Runtime contribution cleanup is host-owned.
  }
}
```

Plugin IDs should be stable, globally unique within the host's plugin namespace,
and suitable for persisted ownership references. Do not derive IDs from display
names or user-editable labels.

## 4. Host composition

The application is the composition root. It constructs only the plugins it
intends to ship and supplies those instances to the runtime.

```dart
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final pluginManager = PluginManager();

// The host has already selected and constructed this compiled implementation.
await pluginManager.activate(GreetingPlugin());

// On host shutdown or when disabling the plugin:
await pluginManager.deactivate('example.greeting');
```

This example assumes the `GreetingPlugin` class above is imported by the host.
Do not put product-specific plugin lists into a generic Alhambra package.

## 5. Use PluginContext responsibly

The current `PluginContext` exposes:
- `pluginId`: the owner ID used for contribution registration and cleanup.
- `ui`: registrars for views, activity bar, toolbar, status bar, menus,
  navigation, settings, workspace modes and layouts.
- `commands`: command registrar.
- `context`: context-contributor registrar.
- `capabilities`: a capability support query.

Register contributions during activation and use the plugin's own ID as the
ownership boundary. Avoid global mutable state and do not retain host objects
past deactivation unless the API explicitly permits it.

A capability support query is not an authorization check. The host must enforce
permissions and policy at the operation boundary, including for commands and
external services.

## 6. Lifecycle and failure behavior

The current `PluginManager`:
- serializes operations for the same plugin ID;
- treats activation of an already-active plugin as a no-op;
- performs configured capability negotiation before calling plugin activation;
- validates the plugin's registered contributions after activation;
- attempts to unregister partial contributions when activation fails;
- removes host-owned contributions and context during deactivation, even if
  plugin deactivation reports an error.

Do not interpret a failed deactivation as proof that external resources were
released. Plugins should make cleanup explicit and idempotent where possible,
and hosts should surface failures for operator review.

If activation or deactivation can trigger external side effects, document the
side-effect boundary and recovery behavior. Never assume a crash makes retry
safe. Use stable operation identities and host approval for ambiguous recovery.

## 7. Capabilities are declarations, not permissions

Plugin metadata may declare capability IDs. Hosts may negotiate declared
requirements against providers before activation. A successful compatibility
result does not grant access to protected data or services. Enforce authorization
separately through host policy and the capability broker/service boundary.

Declare only capabilities the plugin actually requires. Distinguish required
from optional requirements in the host's requirement resolver rather than
assuming every metadata declaration is mandatory.

## 8. UI contribution guidance

Use the narrowest registrar and contribution model available. Keep widgets
presentation-focused; pass data through explicit models and callbacks. Do not
import product domain repositories into reusable contribution widgets.

For each contribution, document:
- stable contribution ID and owning plugin ID;
- target surface and placement;
- required/preferred capability assumptions;
- behavior when the host surface is unavailable;
- accessibility labels, keyboard/focus behavior and responsive constraints;
- cleanup and state ownership.

The host decides which surfaces and contributions are enabled. A contribution
being registered does not imply that the host must display or authorize it.

## 9. Testing checklist

At minimum, test:
- stable metadata and plugin ID;
- activation success and duplicate activation;
- activation failure after partial registration;
- deactivation success and deactivation failure;
- contribution ownership and cleanup;
- behavior when a capability requirement is not met;
- host behavior when a contribution's target surface is unavailable.

Use fake services and deterministic inputs. Keep network and database integration
tests in the corresponding adapter or host test suite.

## 10. Compatibility and publishing

Treat metadata IDs, contribution IDs, public constructors and persisted fields
as compatibility-sensitive. Prefer additive API changes. For breaking changes,
publish a migration note and update the package changelog and central docs.

Before publishing a plugin, verify its Dart/Flutter SDK constraints, dependency
versions, license compatibility, transitive dependency footprint and host
compatibility. Do not claim compatibility with a host version unless it has
been tested against that version.

## 11. Current limitations

This guide reflects the current API surface. It does not claim:
- arbitrary runtime code download or hot installation;
- plugin process isolation or a security sandbox;
- automatic permission grants from capability negotiation;
- crash-safe cleanup of arbitrary external side effects;
- exactly-once execution of plugin effects.

Those guarantees require explicit host and infrastructure designs beyond the
plugin interface itself.

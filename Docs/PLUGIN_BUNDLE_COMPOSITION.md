# Explicit Plugin Bundle Composition

Alhambra's plugin runtime is reusable infrastructure. It should not select or
import a universal set of application features.

## Ownership boundaries

- `alhambra_plugin_api` defines plugin contracts.
- `alhambra_plugin_runtime` owns registration, activation, lifecycle, and
  contribution cleanup.
- The generic app-side loader accepts plugin instances from its host; it does
  not import product plugins.
- Each deployable application owns its own bundle composition.
- Product-specific packs (Cifr coding, Wayang low-code, analytics, etc.) are
  injected by the host application.

## Explicit composition

The standalone Alhambra Community app currently opts into
`AlhambraCommunityPluginBundle`. An embedding app can provide a smaller
selection or its own domain packs:

```dart
final loader = BuiltInPluginLoader(
  pluginManager: pluginManager,
  platformPlugins: [
    NavigationPlugin(),
    SettingsPlugin(),
  ],
  domainPluginPacks: [
    WayangPluginPack(),
  ],
  onPluginError: (plugin, error, stackTrace) {
    logger.error(
      'Could not activate ${plugin.metadata.id}',
      error,
      stackTrace,
    );
  },
);

final report = await loader.loadAll();
if (report.hasFailures) {
  // Surface startup health in diagnostics or an admin screen.
}
```

Only imported plugin implementations are candidates for inclusion in the
application binary. This is compile-time composition and Flutter tree-shaking,
not arbitrary download-and-execute of Dart code.

## Failure behavior

The loader attempts independent plugins even if one activation fails. It
returns a `PluginLoadReport` containing activated IDs and structured failures,
and optionally invokes a host error callback. It no longer silently swallows
plugin activation exceptions.

The plugin manager remains responsible for rolling back contributions from a
plugin whose activation fails. The host decides whether a partial startup is
acceptable, should be degraded, or should be blocked.

## Domain packs

The `injectedDomainPluginPacksProvider` is separate from edition-gated Pro
plugins. It allows an embedding application to opt into its own product
composition without making those product packages dependencies of Alhambra's
generic plugin loader.

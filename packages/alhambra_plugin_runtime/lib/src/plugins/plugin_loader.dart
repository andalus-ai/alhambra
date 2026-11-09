import 'dart:convert';
import 'dart:io';

import 'extension_manifest.dart';
import 'plugin_dependency_resolver.dart';

/// A discovered plugin.
///
/// It contains the manifest and the directory of the plugin.
class DiscoveredPlugin {
  /// The manifest of the plugin.
  final ExtensionManifest manifest;

  /// The directory of the plugin.
  final Directory directory;

  const DiscoveredPlugin({required this.manifest, required this.directory});
}

/// The plugin loader is responsible for discovering plugin manifests.
///
/// Discovery does not execute plugin code. Hosts remain responsible for
/// validating trust and constructing the compiled plugin instances they ship.
class PluginLoader {
  /// Returns the plugin directories.
  ///
  /// It is called by the plugin loader to get the current context.
  static List<String> get pluginDirectories {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';

    return [
      '${Directory.current.path}/.alhambra/plugins',
      '${Directory.current.path}/plugins',
      '$home/.alhambra/extensions',
      '$home/.andalus/extensions',
    ];
  }

  /// Discovers manifests without imposing dependency ordering.
  ///
  /// This preserves the historical behavior for callers that need the raw
  /// discovery result. Use [scanPluginsInDependencyOrder] for startup.
  static Future<List<DiscoveredPlugin>> scanPlugins() async {
    final discovered = <DiscoveredPlugin>[];

    for (final path in pluginDirectories) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;

      try {
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final manifestFile = File('${entity.path}/plugin.json');
            if (manifestFile.existsSync()) {
              try {
                final content = await manifestFile.readAsString();
                final json = jsonDecode(content) as Map<String, dynamic>;
                final manifest = ExtensionManifest.fromJson(json);
                discovered.add(
                  DiscoveredPlugin(manifest: manifest, directory: entity),
                );
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    return discovered;
  }

  /// Discovers plugins and returns them in dependency-first startup order.
  ///
  /// Required dependencies are validated before a caller can begin
  /// activation. Missing dependencies, duplicate IDs, and cycles are
  /// reported by [PluginDependencyResolver] and are never silently skipped.
  static Future<List<DiscoveredPlugin>>
      scanPluginsInDependencyOrder() async {
    return resolveDependencyOrder(await scanPlugins());
  }

  /// Resolves an already-discovered collection into startup order.
  ///
  /// The original [DiscoveredPlugin] objects and their directories are
  /// retained. The returned list is immutable.
  static List<DiscoveredPlugin> resolveDependencyOrder(
    Iterable<DiscoveredPlugin> discovered, {
    PluginDependencyResolver resolver = const PluginDependencyResolver(),
  }) {
    final plugins = discovered.toList(growable: false);
    final byManifest = Map<ExtensionManifest, DiscoveredPlugin>.identity();

    for (final plugin in plugins) {
      byManifest[plugin.manifest] = plugin;
    }

    final plan = resolver.resolve(
      plugins.map((plugin) => plugin.manifest).toList(growable: false),
    );

    return List<DiscoveredPlugin>.unmodifiable(
      plan.map((manifest) => byManifest[manifest]!),
    );
  }
}

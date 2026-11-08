import 'dart:convert';
import 'dart:io';

import 'extension_manifest.dart';

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

/// The plugin loader is responsible for loading plugins from the file system.
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
}

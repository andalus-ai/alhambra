import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

DiscoveredPlugin discovered(
  String id, {
  List<String> dependencies = const [],
}) {
  return DiscoveredPlugin(
    manifest: ExtensionManifest(
      id: id,
      name: id,
      version: '1.0.0',
      dependencies: dependencies,
    ),
    directory: Directory('/plugins/$id'),
  );
}

void main() {
  group('PluginLoader dependency ordering', () {
    test('retains discovered plugin objects in dependency-first order', () {
      final editor = discovered('editor', dependencies: ['commands']);
      final commands = discovered('commands', dependencies: ['core']);
      final core = discovered('core');
      final theme = discovered('theme');

      final result = PluginLoader.resolveDependencyOrder([
        editor,
        theme,
        commands,
        core,
      ]);

      expect(
        result.map((plugin) => plugin.manifest.id).toList(),
        ['commands', 'core', 'editor', 'theme'],
      );
      expect(result[0], same(commands));
      expect(result[1], same(core));
      expect(result[2], same(editor));
      expect(result[3], same(theme));
    });

    test('preserves discovery order for independent plugins', () {
      final first = discovered('first');
      final second = discovered('second');
      final third = discovered('third');

      final result =
          PluginLoader.resolveDependencyOrder([first, second, third]);

      expect(result, [same(first), same(second), same(third)]);
    });

    test('rejects a missing dependency before startup can begin', () {
      expect(
        () => PluginLoader.resolveDependencyOrder([
          discovered('editor', dependencies: ['missing']),
        ]),
        throwsA(
          isA<PluginDependencyResolutionException>().having(
            (error) => error.code,
            'code',
            PluginDependencyErrorCode.missingDependency,
          ),
        ),
      );
    });

    test('returns an immutable ordered collection', () {
      final result =
          PluginLoader.resolveDependencyOrder([discovered('only')]);

      expect(
        () => result.add(discovered('another')),
        throwsUnsupportedError,
      );
    });
  });
}

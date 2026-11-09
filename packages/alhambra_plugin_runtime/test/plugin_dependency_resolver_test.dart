import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

ExtensionManifest manifest(String id, {List<String> dependencies = const []}) =>
    ExtensionManifest(
      id: id,
      name: id,
      version: '1.0.0',
      dependencies: dependencies,
    );

void main() {
  group('PluginDependencyResolver', () {
    const resolver = PluginDependencyResolver();

    test('orders dependencies before dependents', () {
      final result = resolver.resolve([
        manifest('editor', dependencies: ['commands', 'theme']),
        manifest('theme'),
        manifest('commands', dependencies: ['core']),
        manifest('core'),
      ]);

      expect(
        result.map((item) => item.id).toList(),
        ['core', 'commands', 'theme', 'editor'],
      );
    });

    test('preserves input order for independent plugins', () {
      final result = resolver.resolve([
        manifest('first'),
        manifest('second'),
        manifest('third'),
      ]);

      expect(result.map((item) => item.id), ['first', 'second', 'third']);
    });

    test('supports legacy manifests without dependencies', () {
      final result = resolver.resolve([manifest('legacy')]);
      expect(result.single.id, 'legacy');
    });

    test('rejects missing required dependencies', () {
      expect(
        () => resolver.resolve([
          manifest('editor', dependencies: ['missing']),
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

    test('rejects duplicate plugin IDs', () {
      expect(
        () => resolver.resolve([manifest('same'), manifest('same')]),
        throwsA(
          isA<PluginDependencyResolutionException>().having(
            (error) => error.code,
            'code',
            PluginDependencyErrorCode.duplicatePlugin,
          ),
        ),
      );
    });

    test('rejects self dependency', () {
      expect(
        () => resolver.resolve([manifest('self', dependencies: ['self'])]),
        throwsA(
          isA<PluginDependencyResolutionException>().having(
            (error) => error.code,
            'code',
            PluginDependencyErrorCode.cycle,
          ),
        ),
      );
    });

    test('reports multi-plugin dependency cycles', () {
      expect(
        () => resolver.resolve([
          manifest('a', dependencies: ['b']),
          manifest('b', dependencies: ['c']),
          manifest('c', dependencies: ['a']),
        ]),
        throwsA(
          isA<PluginDependencyResolutionException>()
              .having(
                (error) => error.code,
                'code',
                PluginDependencyErrorCode.cycle,
              )
              .having((error) => error.cycle, 'cycle', ['a', 'b', 'c', 'a']),
        ),
      );
    });

    test('returns an immutable activation plan', () {
      final result = resolver.resolve([manifest('one')]);
      expect(() => result.add(manifest('two')), throwsUnsupportedError);
    });
  });
}

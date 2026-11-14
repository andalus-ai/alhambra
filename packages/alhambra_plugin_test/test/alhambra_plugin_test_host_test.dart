import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CommandPlugin implements AlhambraPlugin {
  _CommandPlugin({this.failActivation = false, this.failDeactivation = false});

  final bool failActivation;
  final bool failDeactivation;

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test.command-plugin',
        name: 'Command plugin',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.commands.register(
      const AppCommand(
        id: 'test.command',
        title: 'Test command',
        category: 'Test',
      ),
    );
    if (failActivation) throw StateError('activation failed after registration');
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    if (failDeactivation) throw StateError('deactivation failed');
  }
}

void main() {
  group('AlhambraPluginTestHost', () {
    test('captures contribution changes and verifies owner cleanup', () async {
      final host = AlhambraPluginTestHost();
      final before = host.snapshot();

      await host.activate(_CommandPlugin());

      expect(host.isActive('test.command-plugin'), isTrue);
      expect(host.runtime.commands.contains('test.command'), isTrue);
      expect(host.snapshot().differenceFrom(before)['commands'], 1);

      await host.deactivate('test.command-plugin');

      expect(host.isActive('test.command-plugin'), isFalse);
      expect(host.runtime.commands.contains('test.command'), isFalse);
      expect(host.snapshot().hasSameCountsAs(before), isTrue);
    });

    test('failed activation removes contributions registered before failure', () async {
      final host = AlhambraPluginTestHost();
      final before = host.snapshot();

      await expectLater(
        host.activate(_CommandPlugin(failActivation: true)),
        throwsA(isA<StateError>()),
      );

      expect(host.isActive('test.command-plugin'), isFalse);
      expect(host.runtime.commands.contains('test.command'), isFalse);
      expect(host.snapshot().hasSameCountsAs(before), isTrue);
    });

    test('failed deactivation still removes host-owned contributions', () async {
      final host = AlhambraPluginTestHost();
      await host.activate(_CommandPlugin(failDeactivation: true));

      await expectLater(
        host.deactivate('test.command-plugin'),
        throwsA(isA<StateError>()),
      );

      expect(host.isActive('test.command-plugin'), isFalse);
      expect(host.runtime.commands.contains('test.command'), isFalse);
    });

    test('close attempts cleanup of active plugins', () async {
      final host = AlhambraPluginTestHost();
      await host.activate(_CommandPlugin());

      await host.close();

      expect(host.activePluginIds, isEmpty);
      expect(host.runtime.commands.contains('test.command'), isFalse);
    });
  });
}

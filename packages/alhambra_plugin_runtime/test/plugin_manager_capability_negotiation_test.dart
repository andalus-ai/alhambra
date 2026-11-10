import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _TestPlugin implements AlhambraPlugin {
  _TestPlugin(this.id);
  final String id;
  int activationCount = 0;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: id,
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    activationCount++;
  }
}

void main() {
  const capability = CapabilityId('storage.read');

  group('PluginManager capability negotiation', () {
    test('required incompatibility blocks activation before plugin code', () async {
      final plugin = _TestPlugin('required-capability');
      final manager = PluginManager(
        capabilityNegotiator: const PluginCapabilityNegotiator(),
        capabilityDeclarations: const [
          PluginCapabilityDeclaration(
            id: capability,
            major: 1,
            available: false,
          ),
        ],
        capabilityRequirementsResolver: (_) => const [
          PluginCapabilityRequirement(
            id: capability,
            major: 1,
            required: true,
          ),
        ],
      );

      await expectLater(
        manager.activate(plugin),
        throwsA(isA<PluginCapabilityNegotiationException>()),
      );

      expect(plugin.activationCount, 0);
      expect(manager.activePlugins, isEmpty);
      expect(
        manager.capabilityNegotiations['required-capability']!.canActivate,
        isFalse,
      );
    });

    test('optional incompatibility allows activation and remains observable',
        () async {
      final plugin = _TestPlugin('optional-capability');
      final manager = PluginManager(
        capabilityNegotiator: const PluginCapabilityNegotiator(),
        capabilityDeclarations: const [],
        capabilityRequirementsResolver: (_) => const [
          PluginCapabilityRequirement(
            id: capability,
            major: 1,
            required: false,
          ),
        ],
      );

      await manager.activate(plugin);

      expect(plugin.activationCount, 1);
      expect(manager.activePlugins, [same(plugin)]);
      final result =
          manager.capabilityNegotiations['optional-capability']!;
      expect(result.status, CapabilityNegotiationStatus.degraded);
      expect(result.canActivate, isTrue);
      expect(result.issues.single.blocking, isFalse);
    });

    test('legacy manager remains compatible when negotiation is omitted',
        () async {
      final plugin = _TestPlugin('legacy-plugin');
      final manager = PluginManager();

      await manager.activate(plugin);

      expect(plugin.activationCount, 1);
      expect(manager.activePlugins, [same(plugin)]);
      expect(manager.capabilityNegotiations, isEmpty);
    });

    test('requires negotiator and requirement resolver together', () {
      expect(
        () => PluginManager(
          capabilityNegotiator: const PluginCapabilityNegotiator(),
        ),
        throwsArgumentError,
      );
      expect(
        () => PluginManager(
          capabilityRequirementsResolver: (_) => const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

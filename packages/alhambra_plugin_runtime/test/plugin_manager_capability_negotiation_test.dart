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
          PluginCapabilityRequirement(id: capability, major: 1),
        ],
      );

      await expectLater(
        manager.activate(plugin),
        throwsA(isA<PluginCapabilityNegotiationException>()),
      );
      expect(plugin.activationCount, 0);
      expect(manager.activePlugins, isEmpty);
      expect(manager.capabilityNegotiations['required-capability']!.canActivate,
          isFalse);
    });

    test('optional incompatibility permits activation and remains observable',
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
      expect(manager.capabilityNegotiations['optional-capability']!.status,
          CapabilityNegotiationStatus.degraded);
    });

    test('legacy manager remains compatible when negotiation is omitted',
        () async {
      final plugin = _TestPlugin('legacy-plugin');
      final manager = PluginManager();
      await manager.activate(plugin);
      expect(plugin.activationCount, 1);
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
        () => PluginManager(capabilityRequirementsResolver: (_) => const []),
        throwsArgumentError,
      );
    });
  });

  group('PluginManager dynamic capability providers', () {
    test('captures current provider revision for each activation', () async {
      final providers = CapabilityProviderRegistry();
      providers.register(
        ownerId: 'storage-provider',
        declarations: const [
          PluginCapabilityDeclaration(id: capability, major: 1, minor: 1),
        ],
      );
      final plugin = _TestPlugin('dynamic-provider');
      final manager = PluginManager(
        capabilityNegotiator: const PluginCapabilityNegotiator(),
        capabilityProviderRegistry: providers,
        capabilityRequirementsResolver: (_) => const [
          PluginCapabilityRequirement(
            id: capability,
            major: 1,
            minimumMinor: 1,
          ),
        ],
      );

      await manager.activate(plugin);
      expect(plugin.activationCount, 1);
      expect(
        manager.capabilityNegotiationRecords['dynamic-provider']!
            .providerRevision,
        1,
      );
      await providers.close();
    });

    test('subsequent activation sees provider withdrawal and blocks', () async {
      final providers = CapabilityProviderRegistry();
      providers.register(
        ownerId: 'storage-provider',
        declarations: const [
          PluginCapabilityDeclaration(id: capability, major: 1),
        ],
      );
      final manager = PluginManager(
        capabilityNegotiator: const PluginCapabilityNegotiator(),
        capabilityProviderRegistry: providers,
        capabilityRequirementsResolver: (_) => const [
          PluginCapabilityRequirement(id: capability, major: 1),
        ],
      );

      await manager.activate(_TestPlugin('first-plugin'));
      expect(providers.unregister('storage-provider'), isTrue);

      final second = _TestPlugin('second-plugin');
      await expectLater(
        manager.activate(second),
        throwsA(isA<PluginCapabilityNegotiationException>().having(
          (error) => error.providerRevision,
          'providerRevision',
          2,
        )),
      );
      expect(second.activationCount, 0);
      expect(
        manager.capabilityNegotiationRecords['second-plugin']!
            .providerRevision,
        2,
      );
      await providers.close();
    });

    test('rejects mixing dynamic registry and static declarations', () {
      final providers = CapabilityProviderRegistry();
      expect(
        () => PluginManager(
          capabilityNegotiator: const PluginCapabilityNegotiator(),
          capabilityProviderRegistry: providers,
          capabilityDeclarations: const [
            PluginCapabilityDeclaration(id: capability, major: 1),
          ],
          capabilityRequirementsResolver: (_) => const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

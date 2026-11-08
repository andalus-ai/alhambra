import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra/providers/module_manager_provider.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

void main() {
  group('UI-13 / UI-14 / UI-15 / UI-16 Riverpod Providers Integration', () {
    test('UI-13: Command dispatcher and interaction registry work via Riverpod', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(interactionRegistryProvider);
      final dispatcher = container.read(commandDispatcherProvider);

      const cmd = CommandType('git', 'sync');
      registry.registerCommand(
        const CommandDefinition(type: cmd, title: 'Sync Repository'),
        handler: (c, ctx) async => const ResourceMutationResult.ok('Synced'),
      );

      final result = await dispatcher.dispatch(
        const ResourceCommand(type: cmd),
        const InteractionContext(),
      );

      expect(result.success, isTrue);
      expect(result.message, 'Synced');
    });

    test('UI-15: Capability broker evaluates and tracks scoped requests via Riverpod', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final broker = container.read(capabilityBrokerProvider);
      const context = CapabilityContext(
        pluginId: PluginId('terminal_plugin'),
        scopeKind: CapabilityScopeKind.workspace,
        scopeId: 'session_ws_1',
      );

      final isInitiallyGranted = broker.isGranted(
        BrokerStandardCapabilities.terminal,
        context,
      );
      expect(isInitiallyGranted, isFalse);
    });

    test('UI-16: Scoped contribution manager handles leases and cleanup via Riverpod', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final extRegistry = container.read(extensionContributionRegistryProvider);
      final manager = container.read(scopedContributionManagerProvider);

      final contrib = _MockContribution(
        id: const ContributionId('custom.view.sidebar'),
        pluginId: const PluginId('custom_plugin'),
      );

      final lease = manager.registerInScope('scope-view-2', contrib);
      expect(extRegistry.find(const ContributionId('custom.view.sidebar')), isNotNull);

      lease.dispose();
      expect(extRegistry.find(const ContributionId('custom.view.sidebar')), isNull);
    });
  });
}

class _MockContribution implements ExtensionUiContribution {
  @override
  final ContributionId id;
  @override
  final PluginId pluginId;

  _MockContribution({required this.id, required this.pluginId});
}

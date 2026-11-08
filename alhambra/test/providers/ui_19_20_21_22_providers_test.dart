import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import 'package:alhambra/providers/module_manager_provider.dart';

void main() {
  group('UI-19 to UI-22 Riverpod Providers Test', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('uiProjectionRegistryProvider provides registry', () {
      final registry = container.read(uiProjectionRegistryProvider);
      expect(registry, isNotNull);
      expect(registry, isA<UiProjectionRegistry>());
    });

    test('packaging & verification providers are wired', () {
      final trustStore = container.read(pluginTrustStoreProvider);
      final verifier = container.read(pluginPackageVerifierProvider);
      final store = container.read(installedPluginStoreProvider);

      expect(trustStore, isNotNull);
      expect(verifier, isNotNull);
      expect(store, isNotNull);
    });

    test('discovery & lifecycle manager providers are wired', () {
      final catalog = container.read(pluginCatalogProvider);
      final lifecycle = container.read(pluginLifecycleManagerProvider);

      expect(catalog, isNotNull);
      expect(lifecycle, isNotNull);
    });

    test('workspace manager and alhambra UI context providers are wired', () {
      final wsManager = container.read(workspaceManagerProvider);
      final uiContext = container.read(alhambraUIContextProvider);

      expect(wsManager, isNotNull);
      expect(uiContext.profile.edition, equals(ProductEdition.community));
      expect(uiContext.workspaceManager, equals(wsManager));
    });
  });
}

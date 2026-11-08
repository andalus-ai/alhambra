import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra/core/license/edition.dart';
import 'package:alhambra/core/license/pro_plugin_host.dart';

class _MockGovernancePlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'alhambra.pro.governance',
        name: 'Mock Governance',
        version: '1.0.0',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: 'alhambra.pro.governance.dashboard',
        ownerId: metadata.id,
        title: 'Governance',
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

void main() {
  group('ProPluginHost Integration Tests', () {
    late PluginManager pluginManager;
    late ProPluginHost host;

    setUp(() {
      pluginManager = PluginManager();
      host = ProPluginHost(
        pluginManager: pluginManager,
        proPlugins: [_MockGovernancePlugin()],
      );
    });

    test('Activating Pro edition dynamically activates Governance plugin', () async {
      await host.syncPlugins(AlhambraEdition.pro);

      expect(pluginManager.activePlugins.length, 1);
      expect(pluginManager.runtime.views.get('alhambra.pro.governance.dashboard'), isNotNull);
    });

    test('Switching to Community edition cleanly deactivates Pro plugins', () async {
      // First activate Pro
      await host.syncPlugins(AlhambraEdition.pro);
      expect(pluginManager.activePlugins.isNotEmpty, isTrue);

      // Switch to Community
      await host.syncPlugins(AlhambraEdition.community);

      expect(pluginManager.activePlugins.isEmpty, isTrue);
      expect(pluginManager.runtime.views.get('alhambra.pro.governance.dashboard'), isNull);
    });
  });
}

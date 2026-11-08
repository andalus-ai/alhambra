import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../plugin/screens/plugin_manager_screen.dart';

class MarketplacePlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.marketplace';
  static const viewId = 'alhambra.marketplace.view';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Alhambra Extension Marketplace',
        version: '1.0.0',
        description: 'Discovery and installation of community and pro plugins',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: viewId,
        ownerId: pluginId,
        title: 'Extensions',
        icon: Icons.extension_outlined,
        preferredPlacement: ViewPlacement.sidebar,
        behavior: ViewBehavior.panel,
        builder: (_) => const PluginManagerScreen(),
      ),
    );

    context.ui.activityBar.register(
      ActivityBarContribution(
        id: 'alhambra.activity.extensions',
        ownerId: pluginId,
        label: 'Extensions',
        icon: Icons.extension_outlined,
        activeIcon: Icons.extension,
        section: ActivityBarSection.secondary,
        defaultViewId: viewId,
        order: 40,
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

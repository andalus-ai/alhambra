import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../widgets/sidebar/sidebar_widget.dart';

class ExplorerPlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.explorer';
  static const viewId = 'alhambra.explorer.tree';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Alhambra File Explorer',
        version: '1.0.0',
        description: 'Workspace file tree and project navigation',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: viewId,
        ownerId: pluginId,
        title: 'Explorer',
        icon: Icons.folder_copy_outlined,
        preferredPlacement: ViewPlacement.sidebar,
        behavior: ViewBehavior.panel,
        builder: (_) => const SidebarWidget(),
      ),
    );

    context.ui.activityBar.register(
      ActivityBarContribution(
        id: 'alhambra.activity.explorer',
        ownerId: pluginId,
        label: 'Explorer',
        icon: Icons.folder_copy_outlined,
        activeIcon: Icons.folder_copy,
        section: ActivityBarSection.primary,
        defaultViewId: viewId,
        order: 10,
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

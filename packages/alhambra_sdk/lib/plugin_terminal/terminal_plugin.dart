import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'widgets/terminal_panel.dart';

class TerminalPlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.terminal';
  static const viewId = 'alhambra.terminal.main';

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: pluginId,
    name: 'Alhambra Integrated Terminal',
    version: '1.0.0',
    description: 'Interactive shell execution in the active workspace',
  );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: viewId,
        ownerId: pluginId,
        title: 'Terminal',
        icon: Icons.terminal_rounded,
        preferredPlacement: ViewPlacement.bottomPanel,
        behavior: ViewBehavior.panel,
        builder: (_) => const TerminalPanel(),
      ),
    );

    context.commands.register(
      AppCommand(
        id: 'alhambra.terminal.toggle',
        title: 'View: Toggle Integrated Terminal',
        category: 'Terminal',
        icon: Icons.terminal_rounded,
        action: (cmdCtx) {},
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'widgets/logs_viewer_dialog.dart';

class LogPlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.log';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Alhambra Log Viewer',
        version: '1.0.0',
        description: 'Multi-scope log viewer with JSON and structured inspection',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.commands.register(
      AppCommand(
        id: 'alhambra.log.open',
        title: 'Logs: Open System Logs Viewer',
        category: 'Developer',
        icon: Icons.article_outlined,
        action: (cmdCtx) {},
      ),
    );

    context.ui.toolbar.register(
      ToolbarContribution(
        id: 'alhambra.toolbar.logs',
        ownerId: pluginId,
        targetId: ToolbarTargets.app,
        alignment: ToolbarAlignment.end,
        kind: ToolbarItemKind.action,
        icon: Icons.article_outlined,
        tooltip: 'System Logs',
        order: 75,
        action: (ctx) {
          showDialog(
            context: ctx,
            barrierDismissible: true,
            builder: (_) => const LogsViewerDialog(),
          );
        },
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

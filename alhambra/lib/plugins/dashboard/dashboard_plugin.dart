import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'widgets/metric_dashboard.dart';

class DashboardPlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.dashboard';
  static const viewId = 'alhambra.dashboard.view';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Alhambra Metrics & Analytics Dashboard',
        version: '1.0.0',
        description: 'Performance metrics, model inference latencies, and token utilization telemetry',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.views.register(
      ViewContribution(
        id: viewId,
        ownerId: pluginId,
        title: 'Dashboard',
        icon: Icons.speed,
        preferredPlacement: ViewPlacement.main,
        behavior: ViewBehavior.editor,
        builder: (_) => const MetricsDashboard(),
      ),
    );

    context.commands.register(
      AppCommand(
        id: 'alhambra.dashboard.open',
        title: 'Dashboard: Open Inference Analytics',
        category: 'Analytics',
        icon: Icons.speed,
        action: (cmdCtx) {},
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

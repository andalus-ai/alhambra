import 'package:flutter/material.dart';

import '../models/plugin.dart';

class PluginIcon extends StatelessWidget {
  final Plugin plugin;

  const PluginIcon({super.key, required this.plugin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getIcon(), color: _getColor(), size: 20),
    );
  }

  Color _getColor() {
    if (plugin.isUploaded) return Colors.orange;
    if (plugin.type == PluginType.marketplace) return Colors.purple;
    if (plugin.type == PluginType.repository) return Colors.teal;
    if (plugin.status == PluginStatus.error) return Colors.red;
    if (plugin.status == PluginStatus.pendingRestart) return Colors.orange;
    return Colors.blue;
  }

  IconData _getIcon() {
    if (plugin.isUploaded) return Icons.cloud_upload;
    if (plugin.type == PluginType.marketplace) return Icons.storefront;
    if (plugin.type == PluginType.repository) return Icons.code;
    if (plugin.status == PluginStatus.error) return Icons.error_outline;
    if (plugin.status == PluginStatus.pendingRestart) return Icons.restart_alt;
    return Icons.extension;
  }
}

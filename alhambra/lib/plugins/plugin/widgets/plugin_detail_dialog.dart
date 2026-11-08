import 'package:flutter/material.dart';

import '../models/plugin.dart';
import 'detail_row.dart';
import 'plugin_icon.dart';

class PluginDetailsDialog extends StatelessWidget {
  final Plugin plugin;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onDelete;
  final Function(String) onOpenHomepage;

  const PluginDetailsDialog({
    super.key,
    required this.plugin,
    required this.onInstall,
    required this.onUninstall,
    required this.onDelete,
    required this.onOpenHomepage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: _buildTitle(),
      content: _buildContent(),
      actions: _buildActions(context),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        PluginIcon(plugin: plugin),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            plugin.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow('Author', label: 'Author', value: plugin.author),
          DetailRow('Version', label: 'Version', value: plugin.version),
          DetailRow('Type',
              label: 'Type', value: plugin.type.toString().split('.').last),
          DetailRow('Status',
              label: 'Status', value: plugin.status.toString().split('.').last),
          DetailRow('Last Updated',
              label: 'Last Updated', value: plugin.formattedDate),
          if (plugin.downloads > 0)
            DetailRow('Downloads',
                label: 'Downloads', value: plugin.formattedDownloads),
          if (plugin.rating > 0)
            DetailRow('Rating',
                label: 'Rating',
                value: '${plugin.rating.toStringAsFixed(1)} ★'),
          if (plugin.description != null)
            DetailRow('Description',
                label: 'Description',
                value: plugin.description!,
                multiline: true),
          if (plugin.capabilities.isNotEmpty)
            DetailRow('Capabilities',
                label: 'Capabilities', value: plugin.capabilities.join(', ')),
          if (plugin.tags.isNotEmpty)
            DetailRow('Tags', label: 'Tags', value: plugin.tags.join(', ')),
          if (plugin.metadata.isNotEmpty)
            DetailRow('Metadata',
                label: 'Metadata', value: plugin.metadata.toString()),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ];

    if (plugin.homepage != null) {
      actions.add(
        TextButton(
          onPressed: () => onOpenHomepage(plugin.homepage!),
          child: const Text('Visit Homepage'),
        ),
      );
    }

    if (!plugin.isInstalled) {
      actions.add(
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onInstall();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Install'),
        ),
      );
    } else {
      actions.add(
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (plugin.isUploaded || plugin.isFromRepository) {
              onDelete();
            } else {
              onUninstall();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(plugin.isUploaded ? 'Delete' : 'Uninstall'),
        ),
      );
    }

    return actions;
  }
}

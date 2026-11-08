import 'package:flutter/material.dart';

import '../models/plugin.dart';

class PluginOptionsBottomSheet extends StatelessWidget {
  final Plugin plugin;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  final VoidCallback onCheckUpdates;
  final Function(String) onOpenHomepage;
  final Function(Plugin) onShare;

  const PluginOptionsBottomSheet({
    super.key,
    required this.plugin,
    required this.onInstall,
    required this.onUninstall,
    required this.onDelete,
    required this.onDetails,
    required this.onCheckUpdates,
    required this.onOpenHomepage,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('Details'),
            subtitle: Text('v${plugin.version}'),
            onTap: onDetails,
          ),
          if (!plugin.isInstalled)
            ListTile(
              leading: const Icon(Icons.download_outlined, color: Colors.green),
              title: const Text('Install'),
              subtitle: Text('${plugin.formattedDownloads} downloads'),
              onTap: onInstall,
            ),
          if (plugin.isInstalled && plugin.type == PluginType.marketplace)
            ListTile(
              leading: const Icon(Icons.update, color: Colors.blue),
              title: const Text('Check for Updates'),
              onTap: onCheckUpdates,
            ),
          if (plugin.isInstalled && !plugin.isUploaded)
            ListTile(
              leading: const Icon(
                Icons.disabled_by_default_outlined,
                color: Colors.orange,
              ),
              title: const Text('Uninstall'),
              onTap: onUninstall,
            ),
          if (plugin.isUploaded || plugin.isFromRepository)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Plugin'),
              subtitle: const Text('Remove permanently'),
              onTap: onDelete,
            ),
          if (plugin.homepage != null)
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Colors.blue),
              title: const Text('View Homepage'),
              onTap: () => onOpenHomepage(plugin.homepage!),
            ),
          if (plugin.repositoryUrl != null)
            ListTile(
              leading: const Icon(Icons.code, color: Colors.purple),
              title: const Text('View Repository'),
              onTap: () => onOpenHomepage(plugin.repositoryUrl!),
            ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.grey),
            title: const Text('Share Plugin'),
            onTap: () => onShare(plugin),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

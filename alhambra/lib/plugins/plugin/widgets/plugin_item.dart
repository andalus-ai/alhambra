import 'package:flutter/material.dart';

import '../models/plugin.dart';
import 'installed_indicator.dart';
import 'plugin_icon.dart';
import 'plugin_status_chip.dart';

class PluginItem extends StatelessWidget {
  final Plugin plugin;
  final bool isInstalling;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onDelete;
  final VoidCallback onShowOptions;
  final VoidCallback onShowDetails;

  const PluginItem({
    super.key,
    required this.plugin,
    required this.isInstalling,
    required this.onInstall,
    required this.onUninstall,
    required this.onDelete,
    required this.onShowOptions,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(isDark),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onShowDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PluginIcon(plugin: plugin),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(),
                    const SizedBox(height: 4),
                    _buildSubtitle(context),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Align(
                  alignment: Alignment.topRight,
                  child: _buildTrailing(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(bool isDark) {
    if (plugin.isUploaded) return Colors.orange.withValues(alpha: 0.3);
    if (plugin.type == PluginType.marketplace) {
      return Colors.purple.withValues(alpha: 0.3);
    }
    return isDark ? Colors.grey[800]! : Colors.grey[200]!;
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            plugin.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (plugin.isUploaded) ...[
          const SizedBox(width: 8),
          const PluginStatusChip('Uploaded', Colors.orange),
        ],
        if (plugin.type == PluginType.marketplace) ...[
          const SizedBox(width: 8),
          const PluginStatusChip('Marketplace', Colors.purple),
        ],
        if (plugin.type == PluginType.repository) ...[
          const SizedBox(width: 8),
          const PluginStatusChip('Repository', Colors.teal),
        ],
        if (plugin.status == PluginStatus.pendingRestart) ...[
          const SizedBox(width: 8),
          const PluginStatusChip('Restart', Colors.orange),
        ],
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _buildMetadataRow(isDark),
        if (plugin.description != null) ...[
          const SizedBox(height: 4),
          Text(
            plugin.description!,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (plugin.tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildTags(isDark),
        ],
      ],
    );
  }

  Widget _buildMetadataRow(bool isDark) {
    final metadata = <Widget>[];

    metadata.add(
      Text(
        plugin.author,
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    metadata.addAll([
      const SizedBox(width: 8),
      _buildDot(isDark),
      const SizedBox(width: 8),
      Text(
        'v${plugin.version}',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      const SizedBox(width: 8),
      _buildDot(isDark),
      const SizedBox(width: 8),
      Text(
        plugin.formattedDate,
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
    ]);

    if (plugin.downloads > 0) {
      metadata.addAll([
        const SizedBox(width: 8),
        _buildDot(isDark),
        const SizedBox(width: 8),
        Wrap(
          spacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.download,
              size: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            Text(
              plugin.formattedDownloads,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ]);
    }

    if (plugin.rating > 0) {
      metadata.addAll([
        const SizedBox(width: 8),
        _buildDot(isDark),
        const SizedBox(width: 8),
        Wrap(
          spacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.star, size: 14, color: Colors.amber[400]),
            Text(
              plugin.rating.toStringAsFixed(1),
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ]);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadata,
    );
  }

  Widget _buildDot(bool isDark) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[500] : Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTags(bool isDark) {
    return Wrap(
      spacing: 4,
      children: plugin.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isInstalling) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (plugin.isInstalled) {
      return const InstalledIndicator();
    }

    return IconButton(
      icon: Icon(Icons.more_vert,
          color: isDark ? Colors.grey[400] : Colors.grey[600]),
      onPressed: onShowOptions,
    );
  }
}

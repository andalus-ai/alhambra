import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/models/marketplace.dart';
import '../models/plugin.dart';

class PluginSectionTitle extends ConsumerWidget {
  final AsyncValue<List<Plugin>> pluginsAsync;
  final AsyncValue<List<Marketplace>> marketplacesAsync;

  const PluginSectionTitle({
    super.key,
    required this.pluginsAsync,
    required this.marketplacesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Plugins',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          _buildPluginCount(),
          const Spacer(),
          _buildMarketplaceCount(),
        ],
      ),
    );
  }

  Widget _buildPluginCount() {
    return pluginsAsync.when(
      data: (plugins) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${plugins.length}',
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildMarketplaceCount() {
    return marketplacesAsync.when(
      data: (marketplaces) {
        final totalPlugins = marketplaces.fold<int>(
          0,
          (sum, m) => sum + m.pluginCount,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.storefront, size: 16, color: Colors.blue[300]),
              const SizedBox(width: 4),
              Text(
                '$totalPlugins available',
                style: TextStyle(color: Colors.blue[300], fontSize: 12),
              ),
            ],
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

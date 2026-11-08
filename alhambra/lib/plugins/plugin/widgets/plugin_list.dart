import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/market_place_header.dart';
import '../../marketplace/models/marketplace.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../models/plugin.dart';
import 'empty_state.dart';
import 'plugin_item.dart';

class PluginList extends ConsumerWidget {
  final ScrollController scrollController;
  final AsyncValue<List<Plugin>> pluginsAsync;
  final AsyncValue<List<Marketplace>> marketplacesAsync;
  final Function(Plugin) onInstall;
  final Function(Plugin) onUninstall;
  final Function(Plugin) onDelete;
  final Function(BuildContext, Plugin) onShowOptions;
  final Function(BuildContext, Plugin) onShowDetails;

  const PluginList({
    super.key,
    required this.scrollController,
    required this.pluginsAsync,
    required this.marketplacesAsync,
    required this.onInstall,
    required this.onUninstall,
    required this.onDelete,
    required this.onShowOptions,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMarketplaceId = ref.watch(selectedMarketplaceIdProvider);

    if (selectedMarketplaceId != null) {
      return _buildMarketplaceView(context, selectedMarketplaceId, ref);
    }

    return _buildPluginListView(context, pluginsAsync, ref);
  }

  Widget _buildMarketplaceView(
    BuildContext context,
    String marketplaceId,
    WidgetRef ref,
  ) {
    final pluginsAsync = ref.watch(marketplacePluginsProvider(marketplaceId));
    final marketplacesAsync = ref.watch(marketplaceListProvider);

    return Column(
      children: [
        MarketplaceHeader(
          marketplaceId: marketplaceId,
          marketplacesAsync: marketplacesAsync,
          onClose: () {
            ref.read(selectedMarketplaceIdProvider.notifier).state = null;
          },
        ),
        Expanded(
          child: _buildPluginListView(context, pluginsAsync, ref),
        ),
      ],
    );
  }

  Widget _buildPluginListView(
    BuildContext context,
    AsyncValue<List<Plugin>> pluginsAsync,
    WidgetRef ref,
  ) {
    final isInstalling = ref.watch(isInstallingProvider);

    return pluginsAsync.when(
      data: (plugins) {
        if (plugins.isEmpty) {
          return const EmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: plugins.length,
          itemBuilder: (context, index) {
            final plugin = plugins[index];
            final isInstallingPlugin = isInstalling.contains(plugin.id);

            return PluginItem(
              plugin: plugin,
              isInstalling: isInstallingPlugin,
              onInstall: () => onInstall(plugin),
              onUninstall: () => onUninstall(plugin),
              onDelete: () => onDelete(plugin),
              onShowOptions: () => onShowOptions(context, plugin),
              onShowDetails: () => onShowDetails(context, plugin),
            );
          },
        );
      },
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load plugins',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(pluginListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

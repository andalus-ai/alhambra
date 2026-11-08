import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/models/marketplace.dart';
import '../../marketplace/widgets/marketplace_indicator.dart';

class PluginHeader extends ConsumerWidget {
  final AsyncValue<List<Marketplace>> marketplacesAsync;
  final VoidCallback onAddMarketplace;
  final VoidCallback onSettings;

  const PluginHeader({
    super.key,
    required this.marketplacesAsync,
    required this.onAddMarketplace,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMarketplaces = marketplacesAsync.when(
      data: (marketplaces) => marketplaces.isNotEmpty,
      error: (_, __) => false,
      loading: () => false,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 6,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (hasMarketplaces)
            MarketplaceIndicator(marketplacesAsync: marketplacesAsync),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onAddMarketplace,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[700],
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

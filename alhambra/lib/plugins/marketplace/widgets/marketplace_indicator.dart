import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';

class MarketplaceIndicator extends ConsumerWidget {
  final AsyncValue<List<Marketplace>> marketplacesAsync;

  const MarketplaceIndicator({
    super.key,
    required this.marketplacesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return marketplacesAsync.when(
      data: (marketplaces) {
        final activeCount = marketplaces.where((m) => m.isEnabled).length;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 14, color: Colors.blue[300]),
              const SizedBox(width: 4),
              Text(
                '$activeCount',
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

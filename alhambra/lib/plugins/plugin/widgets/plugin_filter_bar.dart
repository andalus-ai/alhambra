import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/providers/marketplace_provider.dart';

class PluginFilterButton extends ConsumerWidget {
  const PluginFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      onSelected: (value) {
        switch (value) {
          case 'all':
            ref.read(searchQueryProvider.notifier).state = '';
            break;
          case 'installed':
            ref.read(searchQueryProvider.notifier).state = 'installed';
            break;
          case 'official':
            ref.read(searchQueryProvider.notifier).state = 'official';
            break;
          case 'marketplace':
            ref.read(searchQueryProvider.notifier).state = 'marketplace';
            break;
          case 'uploaded':
            ref.read(searchQueryProvider.notifier).state = 'uploaded';
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              Icon(Icons.all_inclusive, size: 20),
              SizedBox(width: 12),
              Text('All Plugins'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'installed',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 20),
              SizedBox(width: 12),
              Text('Installed'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'official',
          child: Row(
            children: [
              Icon(Icons.verified, size: 20),
              SizedBox(width: 12),
              Text('Official'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'marketplace',
          child: Row(
            children: [
              Icon(Icons.storefront, size: 20),
              SizedBox(width: 12),
              Text('Marketplace'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'uploaded',
          child: Row(
            children: [
              Icon(Icons.cloud_upload, size: 20),
              SizedBox(width: 12),
              Text('Uploaded'),
            ],
          ),
        ),
      ],
    );
  }
}

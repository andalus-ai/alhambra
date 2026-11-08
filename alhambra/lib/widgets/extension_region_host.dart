import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../providers/module_manager_provider.dart';

class ExtensionRegionHost extends ConsumerWidget {
  final UiRegion region;

  const ExtensionRegionHost({super.key, required this.region});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(viewRegistryProvider);
    final views = registry.all.where((v) => v.defaultRegion == region).toList();

    if (views.isEmpty) {
      return const SizedBox.shrink();
    }

    if (views.length == 1) {
      return views.first.builder(context);
    }

    // Default to Row for multiple views if no layout manager exists.
    return Row(
      children: [
        for (var i = 0; i < views.length; i++) ...[
          Expanded(child: views[i].builder(context)),
          if (i < views.length - 1) const VerticalDivider(width: 1),
        ],
      ],
    );
  }
}

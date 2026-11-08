import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/module_manager_provider.dart';

class ShellRegionHost extends ConsumerWidget {
  final String regionId;
  final Widget? child;

  const ShellRegionHost({
    super.key,
    required this.regionId,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(resolvedShellRegionProvider(regionId));

    if (!region.visible) {
      return const SizedBox.shrink();
    }

    if (child != null) {
      return child!;
    }

    return const SizedBox.shrink();
  }
}

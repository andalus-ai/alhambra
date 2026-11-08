import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../../providers/module_manager_provider.dart';
import 'contributed_view_host.dart';
import 'layout/layout_node_host.dart';

class WorkbenchArea extends ConsumerWidget {
  final ViewArea area;
  final Widget? fallback;

  const WorkbenchArea({
    super.key,
    required this.area,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workbenchLayoutProvider);
    final root = state.layoutFor(area);

    if (root != null) {
      final viewsInArea = state.viewsIn(area);
      if (viewsInArea.isNotEmpty) {
        return LayoutNodeHost(node: root);
      }
    }

    final activeViewId = state.activeViewIn(area);
    if (activeViewId != null) {
      return ContributedViewHost(viewId: activeViewId);
    }

    final views = ref.watch(viewRegistryProvider).forArea(area);
    if (views.isNotEmpty) {
      return ContributedViewHost(viewId: views.first.id);
    }

    return fallback ?? const SizedBox.shrink();
  }
}

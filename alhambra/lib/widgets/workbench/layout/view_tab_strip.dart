import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import 'view_tab.dart';

class ViewTabStrip extends ConsumerWidget {
  final ViewGroupState group;
  final bool isFocused;

  const ViewTabStrip({
    super.key,
    required this.group,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workbench = ref.watch(workbenchControllerProvider);
    final activeViewId = group.activeViewId;

    if (group.viewIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF090D13),
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final viewId in group.viewIds)
                    ViewTab(
                      viewId: viewId,
                      groupId: group.id,
                      isActive: viewId == activeViewId,
                      isFocused: isFocused,
                    ),
                ],
              ),
            ),
          ),
          if (activeViewId != null) ...[
            IconButton(
              icon: const Icon(Icons.splitscreen_outlined, size: 16),
              tooltip: 'Split Right',
              color: AppTheme.textMuted,
              splashRadius: 14,
              onPressed: () {
                workbench.splitView(
                  activeViewId,
                  direction: SplitDirection.horizontal,
                  placement: SplitPlacement.after,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.vertical_split_outlined, size: 16),
              tooltip: 'Split Down',
              color: AppTheme.textMuted,
              splashRadius: 14,
              onPressed: () {
                workbench.splitView(
                  activeViewId,
                  direction: SplitDirection.vertical,
                  placement: SplitPlacement.after,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

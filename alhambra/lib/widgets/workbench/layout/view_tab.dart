import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import '../docking/dock_drag_data.dart';
import '../docking/dock_overlay.dart';

class ViewTab extends ConsumerWidget {
  final String viewId;
  final String groupId;
  final bool isActive;
  final bool isFocused;

  const ViewTab({
    super.key,
    required this.viewId,
    required this.groupId,
    required this.isActive,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(viewRegistryProvider);
    final workbench = ref.watch(workbenchControllerProvider);
    final contribution = registry.get(viewId);

    final title = contribution?.title ?? viewId;
    final icon = contribution?.icon;
    final closable = contribution?.behavior.closable ?? true;
    final dockable = contribution?.behavior.dockable ?? true;

    final tabWidget = InkWell(
      onTap: () {
        workbench.activateView(viewId);
        workbench.focusGroup(groupId);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.panel : Colors.transparent,
          border: Border(
            top: BorderSide(
              color: isActive
                  ? (isFocused ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.5))
                  : Colors.transparent,
              width: 2,
            ),
            right: const BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.white : AppTheme.textMuted,
              ),
            ),
            if (closable) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => workbench.closeView(viewId),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isActive ? AppTheme.textSecondary : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!dockable) return tabWidget;

    final dragData = DockDragData(viewId: viewId, sourceGroupId: groupId);

    return LongPressDraggable<DockDragData>(
      data: dragData,
      delay: const Duration(milliseconds: 150),
      onDragStarted: () {
        ref.read(dockDragSessionProvider.notifier).begin(dragData, Offset.zero);
      },
      onDragUpdate: (details) {
        ref.read(dockDragSessionProvider.notifier).update(details.globalPosition);
      },
      onDragEnd: (_) {
        ref.read(dockDragSessionProvider.notifier).drop();
      },
      onDraggableCanceled: (_, __) {
        ref.read(dockDragSessionProvider.notifier).cancel();
      },

      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
            ],
            border: Border.all(color: AppTheme.accent),
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tabWidget),
      child: tabWidget,
    );
  }
}

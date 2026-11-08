import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import '../contributed_view_host.dart';
import '../docking/dock_overlay.dart';
import '../docking/dock_target.dart';
import '../docking/dock_target_registry.dart';
import 'view_tab_strip.dart';


class ViewGroupHost extends ConsumerStatefulWidget {
  final String groupId;

  const ViewGroupHost({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<ViewGroupHost> createState() => _ViewGroupHostState();
}

class _ViewGroupHostState extends ConsumerState<ViewGroupHost> {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _tabStripKey = GlobalKey();

  DockTargetRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = ref.read(dockTargetRegistryProvider);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerDockTarget());
  }

  void _registerDockTarget() {
    if (!mounted) return;
    final containerBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final tabStripBox = _tabStripKey.currentContext?.findRenderObject() as RenderBox?;

    if (containerBox != null && containerBox.hasSize) {
      final pos = containerBox.localToGlobal(Offset.zero);
      final bounds = pos & containerBox.size;

      Rect tabStripBounds = Rect.zero;
      if (tabStripBox != null && tabStripBox.hasSize) {
        final tabPos = tabStripBox.localToGlobal(Offset.zero);
        tabStripBounds = tabPos & tabStripBox.size;
      }

      _registry?.register(
            DockTarget(
              groupId: widget.groupId,
              bounds: bounds,
              tabStripBounds: tabStripBounds,
            ),
          );
    }
  }

  @override
  void dispose() {
    _registry?.unregister(widget.groupId);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerDockTarget());

    final layout = ref.watch(workbenchLayoutProvider);
    final workbench = ref.watch(workbenchControllerProvider);
    final group = layout.group(widget.groupId);

    if (group == null) {
      return const SizedBox.shrink();
    }

    final isFocused = layout.activeGroupId(group.area) == group.id;
    final activeViewId = group.activeViewId;

    return Container(
      key: _containerKey,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(
          color: isFocused ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Strip Header
          if (group.viewIds.isNotEmpty)
            KeyedSubtree(
              key: _tabStripKey,
              child: ViewTabStrip(
                group: group,
                isFocused: isFocused,
              ),
            ),

          // Active View Content
          Expanded(
            child: activeViewId != null
                ? Focus(
                    onFocusChange: (hasNavFocus) {
                      if (hasNavFocus) workbench.focusGroup(group.id);
                    },
                    child: ContributedViewHost(viewId: activeViewId),
                  )
                : const Center(
                    child: Text(
                      'No open views in this group',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

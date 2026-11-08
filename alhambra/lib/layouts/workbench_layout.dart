import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/workbench/docking/dock_overlay.dart';
import '../widgets/workbench/slots/activity_bar_slot.dart';
import '../widgets/workbench/slots/bottom_pane_slot.dart';
import '../widgets/workbench/slots/main_pane_slot.dart';
import '../widgets/workbench/slots/secondary_pane_slot.dart';
import '../widgets/workbench/slots/side_pane_slot.dart';

/// Full IDE-style workbench layout.
///
/// Renders a four-column shell on **large** screens, a three-column shell on
/// **medium** screens (secondary panel hidden), and a single-column + drawer
/// approach on **small** screens — matching the classic VS Code / JetBrains
/// workbench model.
///
/// Best for: IDE apps, code editors, coding-agent desktops.
class WorkbenchLayout extends LayoutPlugin {
  static const String id = 'alhambra.layout.workbench';

  const WorkbenchLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: id,
        name: 'Workbench',
        description:
            'Classic multi-pane IDE shell: activity bar, sidebar, editor '
            'area, bottom panel, secondary panel.',
        icon: Icons.developer_mode,
        tags: ['ide', 'desktop', 'workbench'],
        suitableFor: {AppKind.ide, AppKind.desktop, AppKind.codingAgent},
      );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    Widget _slot(String slotId, Widget Function() defaultBuilder) {
      final override = slots.override(slotId);
      return override != null ? override(context) : defaultBuilder();
    }

    return switch (screenClass) {
      // ── Large ────────────────────────────────────────────────────────────
      ScreenClass.large => DockOverlay(
          child: Container(
            color: bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _slot(LayoutSlot.activityBar, () => const ActivityBarSlot()),
                _slot(LayoutSlot.sidebar, () => const SidePaneSlot()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
                      _slot(LayoutSlot.bottomPanel, () => const BottomPaneSlot()),
                    ],
                  ),
                ),
                _slot(LayoutSlot.secondaryPanel, () => const SecondaryPaneSlot()),
              ],
            ),
          ),
        ),

      // ── Medium ───────────────────────────────────────────────────────────
      ScreenClass.medium => DockOverlay(
          child: Container(
            color: bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _slot(LayoutSlot.activityBar, () => const ActivityBarSlot()),
                _slot(LayoutSlot.sidebar, () => const SidePaneSlot()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
                      _slot(LayoutSlot.bottomPanel, () => const BottomPaneSlot()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

      // ── Small ────────────────────────────────────────────────────────────
      ScreenClass.small => _SmallWorkbench(slots: slots),
    };
  }
}

/// Drawer-based workbench for small screens.
class _SmallWorkbench extends StatefulWidget {
  final LayoutSlotConfig slots;
  const _SmallWorkbench({required this.slots});

  @override
  State<_SmallWorkbench> createState() => _SmallWorkbenchState();
}

class _SmallWorkbenchState extends State<_SmallWorkbench> {
  final _key = GlobalKey<ScaffoldState>();

  Widget _slot(String slotId, Widget Function() def) {
    final override = widget.slots.override(slotId);
    return override != null ? override(context) : def();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: _key,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: _slot(LayoutSlot.sidebar, () => const SidePaneSlot()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot())),
          _slot(LayoutSlot.bottomPanel, () => const BottomPaneSlot()),
        ],
      ),
      bottomNavigationBar: _WorkbenchBottomBar(
        activityBarOverride: widget.slots.override(LayoutSlot.activityBar),
        onMenuTap: () => _key.currentState?.openDrawer(),
      ),
    );
  }
}

class _WorkbenchBottomBar extends StatelessWidget {
  final WidgetBuilder? activityBarOverride;
  final VoidCallback onMenuTap;

  const _WorkbenchBottomBar({
    required this.onMenuTap,
    this.activityBarOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            tooltip: 'Open sidebar',
            onPressed: onMenuTap,
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          if (activityBarOverride != null)
            Expanded(child: activityBarOverride!(context))
          else
            const Expanded(child: ActivityBarSlot()),
        ],
      ),
    );
  }
}

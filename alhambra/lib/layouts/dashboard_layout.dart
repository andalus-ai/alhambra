import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/workbench/slots/main_pane_slot.dart';
import '../widgets/workbench/slots/side_pane_slot.dart';

/// Dashboard-style layout for data-oriented applications.
///
/// Structure:
/// ```
/// ┌──────────────────────────────────────────────────────┐
/// │   Nav Sidebar  │           Main content area         │
/// │  (filters /    │  ┌────────────────────────────────┐ │
/// │   navigation)  │  │  Cards / Charts / Data grid    │ │
/// │                │  └────────────────────────────────┘ │
/// └────────────────┴──────────────────────────────────────┘
/// ```
///
/// On **medium** screens the sidebar auto-collapses into an icon rail.
/// On **small** screens a drawer replaces the sidebar.
///
/// Best for: analytics dashboards, admin panels, reporting UIs.
class DashboardLayout extends LayoutPlugin implements ProfileAwareLayoutPlugin {
  static const String id = 'alhambra.layout.dashboard';

  const DashboardLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: id,
        name: 'Dashboard',
        description:
            'Navigation sidebar + scrollable card/chart content area. '
            'Collapses sidebar to icon rail on medium screens.',
        icon: Icons.dashboard_outlined,
        tags: ['dashboard', 'analytics', 'admin', 'data'],
        suitableFor: {AppKind.dashboard, AppKind.desktop},
        profileRequirements: LayoutProfileRequirements(
          requiredCapabilities: {'ui.shell', 'ui.navigation', 'data.visualization'},
          preferredHints: {'dashboard', 'dense-grid'},
        ),
      );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    Widget _slot(String slotId, Widget Function() def) {
      final override = slots.override(slotId);
      return override != null ? override(context) : def();
    }

    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final borderColor = theme.dividerColor;

    return switch (screenClass) {
      // ── Large: full sidebar + content ────────────────────────────────────
      ScreenClass.large => Container(
          color: bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navigation / filter sidebar
              SizedBox(
                width: 240,
                child: _slot(LayoutSlot.sidebar, () => const SidePaneSlot()),
              ),
              VerticalDivider(width: 1, color: borderColor),
              // Main dashboard content
              Expanded(
                child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
              ),
            ],
          ),
        ),

      // ── Medium: collapsed icon rail ──────────────────────────────────────
      ScreenClass.medium => Container(
          color: bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 72,
                child: _slot(LayoutSlot.activityBar, () => const SidePaneSlot()),
              ),
              VerticalDivider(width: 1, color: borderColor),
              Expanded(
                child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
              ),
            ],
          ),
        ),

      // ── Small: bottom nav + full-screen content ──────────────────────────
      ScreenClass.small => _DashboardSmall(slots: slots),
    };
  }
  @override
  Widget buildForProfile(
    BuildContext context, {
    required ScreenClass screenClass,
    required ApplicationProfile applicationProfile,
    required LayoutSlotConfig slots,
  }) =>
      build(
        context,
        screenClass: screenClass,
        appKind: AppKind.custom,
        slots: slots,
      );
}

class _DashboardSmall extends StatefulWidget {
  final LayoutSlotConfig slots;
  const _DashboardSmall({required this.slots});
  @override
  State<_DashboardSmall> createState() => _DashboardSmallState();
}

class _DashboardSmallState extends State<_DashboardSmall> {
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
      body: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
      bottomNavigationBar: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: () => _key.currentState?.openDrawer(),
          ),
        ]),
      ),
    );
  }
}

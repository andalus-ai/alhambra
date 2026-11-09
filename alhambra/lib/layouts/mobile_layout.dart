import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/workbench/slots/main_pane_slot.dart';

/// Mobile-first layout using Flutter's standard [NavigationBar] pattern.
///
/// Structure (small / medium):
/// ```
/// ┌──────────────────────────────────────────────────────┐
/// │                   Top App Bar                        │
/// ├──────────────────────────────────────────────────────┤
/// │                                                      │
/// │                   Main Content                       │
/// │              (fills available space)                 │
/// │                                                      │
/// ├──────────────────────────────────────────────────────┤
/// │          Bottom Navigation / Tab Bar                 │
/// └──────────────────────────────────────────────────────┘
/// ```
///
/// On **large** screens it switches to a [NavigationRail] on the left side,
/// keeping content centred with a max-width constraint.
///
/// Best for: mobile apps, PWAs, simple content-browsing UIs.
class MobileLayout extends LayoutPlugin implements ProfileAwareLayoutPlugin {
  static const String id = 'alhambra.layout.mobile';

  const MobileLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: id,
        name: 'Mobile',
        description:
            'Bottom navigation bar on small/medium screens, navigation rail '
            'on large screens. Content is centred with a readable max-width.',
        icon: Icons.phone_android_outlined,
        tags: ['mobile', 'app', 'bottom-nav', 'pwa'],
        suitableFor: {AppKind.mobile},
        profileRequirements: LayoutProfileRequirements(
          requiredCapabilities: {'ui.shell', 'ui.navigation'},
          preferredHints: {'mobile-first', 'bottom-navigation'},
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

    // Large: left rail + centred content
    if (screenClass == ScreenClass.large) {
      return Container(
        color: bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar acts as NavigationRail
            SizedBox(
              width: 80,
              child: _slot(LayoutSlot.activityBar, () => const _DefaultMobileRail()),
            ),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Small / medium: full-width content + bottom bar
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
        ),
      ),
      bottomNavigationBar:
          _slot(LayoutSlot.activityBar, () => const _DefaultMobileBottomBar()),
    );
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

/// Default mobile navigation rail placeholder — replace via [LayoutSlot.activityBar].
class _DefaultMobileRail extends StatelessWidget {
  const _DefaultMobileRail();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Icon(Icons.menu, color: theme.colorScheme.onSurface.withOpacity(0.7)),
      ),
    );
  }
}

/// Default bottom bar placeholder — replace via [LayoutSlot.activityBar].
class _DefaultMobileBottomBar extends StatelessWidget {
  const _DefaultMobileBottomBar();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      color: theme.colorScheme.surface,
      child: Center(
        child: Text('Bottom Nav',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
      ),
    );
  }
}

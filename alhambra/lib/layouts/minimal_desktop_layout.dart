import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/workbench/slots/main_pane_slot.dart';
import '../theme/app_colors.dart';

/// Minimal desktop layout — a single centred content area with no panels.
///
/// Suitable for simple utilities, settings windows, or apps that manage their
/// own chrome without needing the full workbench infrastructure.
///
/// On all screen sizes the content is centred and constrained to a readable
/// max width (adjusted per tier).
///
/// Best for: preferences windows, about screens, wizard-style flows.
class MinimalDesktopLayout extends LayoutPlugin implements ProfileAwareLayoutPlugin {
  static const String id = 'alhambra.layout.minimal_desktop';

  const MinimalDesktopLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: id,
        name: 'Minimal Desktop',
        description:
            'Clean single-column layout with no panels or toolbars. '
            'Content is centred and width-constrained.',
        icon: Icons.view_stream_outlined,
        tags: ['desktop', 'minimal', 'utility'],
        suitableFor: {AppKind.desktop},
        profileRequirements: LayoutProfileRequirements(
          requiredCapabilities: {'ui.shell'},
          preferredHints: {'minimal', 'single-column'},
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

    final maxWidth = switch (screenClass) {
      ScreenClass.small => 480.0,
      ScreenClass.medium => 720.0,
      ScreenClass.large => 1024.0,
    };

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
        ),
      ),
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

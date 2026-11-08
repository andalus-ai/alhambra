import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../widgets/workbench/slots/main_pane_slot.dart';
import '../widgets/workbench/slots/secondary_pane_slot.dart';
import '../widgets/workbench/slots/bottom_pane_slot.dart';

/// Layout optimised for AI coding-agent / chat-first applications (such as Aljabr).
///
/// Arranges the UI as:
///
/// ```
/// ┌──────────────────────────────────────────────────────┐
/// │                   Top Toolbar                        │
/// ├───────────────────────┬──────────────────────────────┤
/// │                       │                              │
/// │   Chat / Agent Main   │   Code / Diff / Secondary    │
/// │      (primary)        │      (secondary panel)       │
/// │                       │                              │
/// ├───────────────────────┴──────────────────────────────┤
/// │               Bottom: Terminal / Logs                │
/// └──────────────────────────────────────────────────────┘
/// ```
///
/// On **medium** screens the secondary panel collapses to a drawer/sheet.
/// On **small** screens only the chat/main area is visible; secondary and
/// bottom panels are accessible via modal sheets or tabs.
///
/// Best for: AI coding agents, Aljabr-style apps, pair-programming tools.
class CodingAgentLayout extends LayoutPlugin {
  static const String id = 'alhambra.layout.coding_agent';

  const CodingAgentLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: id,
        name: 'Coding Agent',
        description:
            'Chat-primary layout: agent conversation pane on the left, '
            'code/diff on the right, terminal below.',
        icon: Icons.smart_toy_outlined,
        tags: ['ai', 'agent', 'chat', 'coding', 'aljabr'],
        suitableFor: {AppKind.codingAgent, AppKind.ide},
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
      // ── Large: chat | code+secondary  /  terminal below ─────────────────
      ScreenClass.large => Container(
          color: bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chat / main pane (60 % by default)
                    Flexible(
                      flex: 6,
                      child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
                    ),
                    VerticalDivider(width: 1, color: borderColor),
                    // Code / diff / secondary (40 %)
                    Flexible(
                      flex: 4,
                      child: _slot(LayoutSlot.secondaryPanel, () => const SecondaryPaneSlot()),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              // Terminal / logs below
              _slot(LayoutSlot.bottomPanel, () => const BottomPaneSlot()),
            ],
          ),
        ),

      // ── Medium: chat full-width / secondary as overlay ──────────────────
      ScreenClass.medium => Container(
          color: bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
              ),
              Divider(height: 1, color: borderColor),
              _slot(LayoutSlot.bottomPanel, () => const BottomPaneSlot()),
            ],
          ),
        ),

      // ── Small: full-screen chat ──────────────────────────────────────────
      ScreenClass.small => Container(
          color: bg,
          child: _slot(LayoutSlot.mainContent, () => const MainPaneSlot()),
        ),
    };
  }
}

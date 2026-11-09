import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'docking/dock_overlay.dart';
import 'slots/activity_bar_slot.dart';
import 'slots/bottom_pane_slot.dart';
import 'slots/main_pane_slot.dart';
import 'slots/secondary_pane_slot.dart';
import 'slots/side_pane_slot.dart';
import '../platform_breakpoints.dart';

/// Composable Workbench Shell that delegates to the three-tier responsive
/// layout via [GenericWorkbenchLayoutView].
///
/// This widget is kept as a thin shim for backward compatibility and for use
/// in widget tests. In production, prefer using [WorkspaceViewHost] (which
/// also handles mode-specific view builders).
///
/// Layout slots:
/// ```
/// [ ActivityBarSlot ] | [ SidePaneSlot ] | [ MainPaneSlot / BottomPaneSlot ] | [ SecondaryPaneSlot ]
/// ```
///
/// Responsive behaviour mirrors [GenericWorkbenchLayoutView]:
/// * **large** (≥ 1024 dp): full multi-pane workspace layout.
/// * **medium** (600–1023 dp): activity bar + sidebar + main; secondary hidden.
/// * **small** (< 600 dp): main pane only; sidebar accessible as a drawer via
///   [GenericWorkbenchLayoutView] (this shell shows a minimal two-column for
///   test/embedding convenience).
class WorkbenchShell extends ConsumerWidget {
  const WorkbenchShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = PlatformBreakpoints.classFor(constraints.maxWidth);

        return PlatformScreenClass(
          screenClass: screen,
          child: DockOverlay(
            child: switch (screen) {
              ScreenClass.large => const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActivityBarSlot(),
                    SidePaneSlot(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MainPaneSlot(),
                          BottomPaneSlot(),
                        ],
                      ),
                    ),
                    SecondaryPaneSlot(),
                  ],
                ),
              ScreenClass.medium => const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActivityBarSlot(),
                    SidePaneSlot(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MainPaneSlot(),
                          BottomPaneSlot(),
                        ],
                      ),
                    ),
                  ],
                ),
              ScreenClass.small => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MainPaneSlot(),
                    BottomPaneSlot(),
                  ],
                ),
            },
          ),
        );
      },
    );
  }
}

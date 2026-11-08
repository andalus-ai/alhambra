import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../providers/module_manager_provider.dart';
import '../theme/app_colors.dart';
import 'platform_breakpoints.dart';
import 'workbench/modes/workspace_mode_segmented_switch.dart';

/// The application-level top toolbar.
///
/// Renders three zones — [ToolbarAlignment.start] / [center] / [end] —
/// driven by contributed [ToolbarContribution] items.  On small screens the
/// center zone (which hosts the workspace-mode switcher) is hidden to save
/// horizontal space.
///
/// ### Extension points
///
/// * Contribute toolbar items via [ToolbarContribution] from any plugin —
///   they are picked up automatically by [_ToolbarSlot].
/// * Override [targetId] to scope the toolbar to a sub-region (defaults to
///   [ToolbarTargets.app]).
/// * Pass a [contextData] for fine-grained context propagation.
/// * Swap the mode switcher entirely: contribute a widget-kind item to the
///   [ToolbarAlignment.center] slot — it will appear in addition to (or
///   instead of) [WorkspaceModeSegmentedSwitch].
class AppToolbar extends ConsumerWidget {
  final String targetId;
  final ToolbarContext? contextData;

  const AppToolbar({
    super.key,
    this.targetId = ToolbarTargets.app,
    this.contextData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = contextData ?? ToolbarContext(targetId: targetId);
    final screenClass = PlatformBreakpoints.of(context);
    final isSmall = screenClass == ScreenClass.small;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Start zone ──────────────────────────────────────────────────
          _ToolbarSlot(
            targetId: targetId,
            alignment: ToolbarAlignment.start,
            toolbarContext: ctx,
          ),

          const Spacer(),

          // ── Centre zone (hidden on small screens) ───────────────────────
          if (!isSmall)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WorkspaceModeSegmentedSwitch(),
                const SizedBox(width: 8),
                _ToolbarSlot(
                  targetId: targetId,
                  alignment: ToolbarAlignment.center,
                  toolbarContext: ctx,
                ),
              ],
            ),

          const Spacer(),

          // ── End zone ────────────────────────────────────────────────────
          _ToolbarSlot(
            targetId: targetId,
            alignment: ToolbarAlignment.end,
            toolbarContext: ctx,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal slot widget
// ---------------------------------------------------------------------------

class _ToolbarSlot extends ConsumerWidget {
  final String targetId;
  final ToolbarAlignment alignment;
  final ToolbarContext toolbarContext;

  const _ToolbarSlot({
    required this.targetId,
    required this.alignment,
    required this.toolbarContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(toolbarRegistryProvider);
    final items = registry.resolve(toolbarContext, alignment);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) ...[
          _ToolbarItem(item: item, toolbarContext: toolbarContext),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal item widget
// ---------------------------------------------------------------------------

class _ToolbarItem extends ConsumerWidget {
  final ToolbarContribution item;
  final ToolbarContext toolbarContext;

  const _ToolbarItem({
    required this.item,
    required this.toolbarContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.kind) {
      case ToolbarItemKind.command:
        return _CommandToolbarButton(item: item);

      case ToolbarItemKind.action:
        return IconButton(
          tooltip: item.tooltip,
          icon: Icon(item.icon, size: 16, color: AppTheme.textSecondary),
          splashRadius: 16,
          onPressed: item.isEnabled?.call(toolbarContext) == false
              ? null
              : () async {
                  await item.action?.call(context);
                },
        );

      case ToolbarItemKind.widget:
        return item.builder != null
            ? item.builder!(context)
            : const SizedBox.shrink();

      case ToolbarItemKind.menu:
        return IconButton(
          tooltip: item.tooltip,
          icon: Icon(item.icon ?? Icons.more_vert,
              size: 16, color: AppTheme.textSecondary),
          splashRadius: 16,
          onPressed: () {},
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Command toolbar button
// ---------------------------------------------------------------------------

class _CommandToolbarButton extends ConsumerWidget {
  final ToolbarContribution item;

  const _CommandToolbarButton({
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.commandId == null) return const SizedBox.shrink();
    final command = ref.read(commandRegistryProvider).get(item.commandId!);

    if (command == null) return const SizedBox.shrink();

    return IconButton(
      tooltip: item.tooltip ?? command.title,
      icon: Icon(item.icon ?? command.icon,
          size: 16, color: AppTheme.textSecondary),
      splashRadius: 16,
      onPressed: () {
        command.action?.call(CommandContext(context: context));
      },
    );
  }
}

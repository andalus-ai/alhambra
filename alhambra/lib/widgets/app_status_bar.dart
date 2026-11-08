import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../providers/module_manager_provider.dart';
import '../theme/app_colors.dart';
import 'workbench/modes/workspace_mode_status_item.dart';

class AppStatusBar extends ConsumerWidget {
  final StatusBarContext? contextData;

  const AppStatusBar({
    super.key,
    this.contextData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusContext = contextData ?? const StatusBarContext();

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          _StatusBarSlot(
            alignment: StatusBarAlignment.start,
            statusContext: statusContext,
          ),
          const Spacer(),
          _StatusBarSlot(
            alignment: StatusBarAlignment.center,
            statusContext: statusContext,
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusBarSlot(
                alignment: StatusBarAlignment.end,
                statusContext: statusContext,
              ),
              const SizedBox(width: 8),
              const WorkspaceModeStatusItem(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBarSlot extends ConsumerWidget {
  final StatusBarAlignment alignment;
  final StatusBarContext statusContext;

  const _StatusBarSlot({
    required this.alignment,
    required this.statusContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(statusBarRegistryProvider);
    final items = registry.resolve(statusContext, alignment);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) ...[
          _StatusBarItem(item: item, statusContext: statusContext),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatusBarItem extends ConsumerWidget {
  final StatusBarContribution item;
  final StatusBarContext statusContext;

  const _StatusBarItem({
    required this.item,
    required this.statusContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.kind) {
      case StatusBarItemKind.text:
        return _StatusTextItem(item: item, statusContext: statusContext);

      case StatusBarItemKind.command:
        return _StatusCommandItem(item: item);

      case StatusBarItemKind.action:
        return _StatusActionItem(item: item, statusContext: statusContext);

      case StatusBarItemKind.widget:
        return item.builder != null
            ? item.builder!(context, statusContext)
            : const SizedBox.shrink();
    }
  }
}

class _StatusTextItem extends StatelessWidget {
  final StatusBarContribution item;
  final StatusBarContext statusContext;

  const _StatusTextItem({
    required this.item,
    required this.statusContext,
  });

  @override
  Widget build(BuildContext context) {
    final text = item.textBuilder?.call(statusContext) ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusCommandItem extends ConsumerWidget {
  final StatusBarContribution item;

  const _StatusCommandItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.commandId == null) return const SizedBox.shrink();
    final command = ref.read(commandRegistryProvider).get(item.commandId!);
    if (command == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => command.action?.call(CommandContext(context: context)),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null || command.icon != null) ...[
              Icon(item.icon ?? command.icon,
                  size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              item.tooltip ?? command.title,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusActionItem extends StatelessWidget {
  final StatusBarContribution item;
  final StatusBarContext statusContext;

  const _StatusActionItem({
    required this.item,
    required this.statusContext,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => item.action?.call(context, statusContext),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
            ],
            if (item.tooltip != null)
              Text(
                item.tooltip!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../providers/module_manager_provider.dart';
import '../theme/app_colors.dart';

class ContributedContextMenu {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required Offset position,
    required MenuContext menuContext,
  }) async {
    final registry = ref.read(contextMenuRegistryProvider);
    final items = registry.resolve(menuContext);

    if (items.isEmpty) return;

    // Group items
    final groups = <String, List<MenuContribution>>{};
    for (final item in items) {
      final group = item.group ?? '__default__';
      groups.putIfAbsent(group, () => []).add(item);
    }

    final entries = groups.entries.toList();

    await showMenu<void>(
      context: context,
      color: AppTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const PopupMenuDivider(height: 1),
          for (final item in entries[i].value)
            PopupMenuItem<void>(
              enabled: item.isEnabled?.call(menuContext) ?? true,
              height: 32,
              onTap: () async {
                await item.action(menuContext);
              },
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 15, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

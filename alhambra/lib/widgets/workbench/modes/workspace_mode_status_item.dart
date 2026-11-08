import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import 'workspace_mode_menu_dialog.dart';

class WorkspaceModeStatusItem extends ConsumerWidget {
  const WorkspaceModeStatusItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(activeWorkspaceModeProvider);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const WorkspaceModeMenuDialog(),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(activeMode.icon, size: 12, color: AppTheme.accent),
            const SizedBox(width: 4),
            Text(
              activeMode.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

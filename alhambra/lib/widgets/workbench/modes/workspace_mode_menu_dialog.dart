import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';

class WorkspaceModeMenuDialog extends ConsumerWidget {
  const WorkspaceModeMenuDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(workspaceModeRegistryProvider);
    final controller = ref.watch(workspaceModeControllerProvider);
    final activeMode = ref.watch(activeWorkspaceModeProvider);
    final modes = registry.all.toList();

    return Dialog(
      backgroundColor: AppTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize_outlined,
                    size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Switch Workspace Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  splashRadius: 14,
                  color: AppTheme.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a workspace layout preset tailored for your current workflow:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: modes.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppTheme.border),
                itemBuilder: (context, index) {
                  final mode = modes[index];
                  final isSelected = mode.id == activeMode.id;

                  return _ModeListTile(
                    mode: mode,
                    isSelected: isSelected,
                    onTap: () {
                      controller.setMode(mode.id);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeListTile extends StatelessWidget {
  final WorkspaceMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeListTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.sidebarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              mode.icon,
              size: 20,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          mode.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (mode.subtitle != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.panelAlt,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            mode.subtitle!,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      if (mode.shortcut != null)
                        Text(
                          mode.shortcut!,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: AppTheme.accent),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import 'workspace_mode_menu_dialog.dart';

class WorkspaceModeSegmentedSwitch extends ConsumerWidget {
  const WorkspaceModeSegmentedSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(activeWorkspaceModeProvider);
    final controller = ref.watch(workspaceModeControllerProvider);
    final registry = ref.watch(workspaceModeRegistryProvider);

    final allModes = registry.all.toList();

    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.panelAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
            title: 'Vibe',
            icon: Icons.auto_awesome,
            tooltip: 'Vibe Coding Agent Mode (⌘⌥1)',
            isSelected: activeMode.id == CoreWorkspaceModes.vibe,
            onTap: () => controller.setMode(CoreWorkspaceModes.vibe),
          ),
          const SizedBox(width: 2),
          _ModeTab(
            title: 'IDE',
            icon: Icons.space_dashboard_outlined,
            tooltip: 'IDE Workspace Mode (⌘⌥2)',
            isSelected: activeMode.id == CoreWorkspaceModes.ide,
            onTap: () => controller.setMode(CoreWorkspaceModes.ide),
          ),
          if (allModes.length > 2) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const WorkspaceModeMenuDialog(),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.title,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isSelected
                ? Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.5), width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

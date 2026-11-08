import 'package:flutter/material.dart';
import '../theme/color_scheme.dart';
import '../theme/spacing.dart';
import 'ui_workspace_status.dart';

/// Renders workspace title, presentation lifecycle status, version, and actions.
class WorkspaceHeader extends StatelessWidget {
  final String title;
  final UiWorkspaceStatus status;
  final int version;
  final String? subtitle;
  final List<Widget>? actions;

  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.status,
    this.version = 1,
    this.subtitle,
    this.actions,
  });

  Color _statusColor(UiWorkspaceStatus status) {
    return switch (status) {
      UiWorkspaceStatus.draft => AlhambraColors.draft,
      UiWorkspaceStatus.review => AlhambraColors.review,
      UiWorkspaceStatus.approved => AlhambraColors.approved,
      UiWorkspaceStatus.published => AlhambraColors.published,
      UiWorkspaceStatus.superseded => AlhambraColors.superseded,
      UiWorkspaceStatus.archived => AlhambraColors.archived,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AlhambraSpacing.lg,
        vertical: AlhambraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AlhambraSpacing.md),
                    Chip(
                      label: Text(
                        status.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: statusColor,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: AlhambraSpacing.sm),
                    Text(
                      'v$version',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AlhambraSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: AlhambraSpacing.md),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

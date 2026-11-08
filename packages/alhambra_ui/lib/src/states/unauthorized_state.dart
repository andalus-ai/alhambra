import 'package:flutter/material.dart';
import '../theme/spacing.dart';

/// Reusable unauthorized state view displayed when access is denied.
class UnauthorizedState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onAction;
  final String actionLabel;

  const UnauthorizedState({
    super.key,
    this.title = 'Access Denied',
    this.message = 'You do not have the required permissions to view this resource.',
    this.onAction,
    this.actionLabel = 'Go Back',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AlhambraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AlhambraSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AlhambraSpacing.sm),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: AlhambraSpacing.lg),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

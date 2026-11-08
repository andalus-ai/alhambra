import 'package:flutter/material.dart';
import '../view_state/view_state.dart';

/// A compact indicator showing the current sync state of a resource or the
/// global sync queue.
///
/// Renders a colored dot + short label:
/// - synced   → green "Synced"
/// - pending  → amber "Saved locally"
/// - syncing  → blue spinner + "Saving…"
/// - conflict → red "Sync conflict"
/// - authRequired → orange "Sign in required"
class SyncIndicator extends StatelessWidget {
  final UiSyncState state;
  final bool showLabel;

  const SyncIndicator({
    super.key,
    required this.state,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _resolve(context);

    return Semantics(
      label: 'Sync status: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Widget, String) _resolve(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (state) {
      UiSyncState.synced => (
          Colors.green,
          Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
          state.label,
        ),
      UiSyncState.pending => (
          Colors.amber.shade700,
          Icon(Icons.upload_outlined, size: 14, color: Colors.amber.shade700),
          state.label,
        ),
      UiSyncState.syncing => (
          colors.primary,
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          state.label,
        ),
      UiSyncState.refreshing => (
          colors.primary,
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          state.label,
        ),
      UiSyncState.conflict => (
          colors.error,
          Icon(Icons.warning_amber_rounded, size: 14, color: colors.error),
          state.label,
        ),
      UiSyncState.authRequired => (
          Colors.orange,
          Icon(Icons.lock_outline, size: 14, color: Colors.orange),
          state.label,
        ),
    };
  }
}

/// Full-width offline banner shown at the top of the shell when connectivity
/// is lost.
///
/// Automatically hides when [isOffline] is false.
class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final String message;

  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.message = 'Offline — changes will sync when connection returns',
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Semantics(
      label: message,
      child: Material(
        color: Colors.amber.shade700,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline conflict state widget showing that a resource has a sync conflict
/// and optionally providing a resolve action.
class ConflictBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onResolve;

  const ConflictBanner({
    super.key,
    this.message,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Sync conflict: ${message ?? 'This item has a sync conflict'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: colors.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message ?? 'Sync conflict — tap to resolve',
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
            if (onResolve != null)
              TextButton(
                onPressed: onResolve,
                child: Text(
                  'Resolve',
                  style: TextStyle(color: colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

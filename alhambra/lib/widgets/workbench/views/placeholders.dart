import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';

class ViewPlaceholderContext {
  final String viewId;
  final String title;
  final String? pluginId;
  final String? reason;
  final String? requiredEdition;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const ViewPlaceholderContext({
    required this.viewId,
    required this.title,
    this.pluginId,
    this.reason,
    this.requiredEdition,
    this.error,
    this.stackTrace,
    this.onRetry,
  });
}

class MissingViewPlaceholder extends ConsumerWidget {
  final ViewPlaceholderContext contextData;

  const MissingViewPlaceholder({
    super.key,
    required this.contextData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(commandRegistryProvider);
    final workbench = ref.watch(workbenchControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_off_outlined,
                  size: 36, color: AppTheme.textMuted),
              const SizedBox(height: 10),
              Text(
                contextData.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                contextData.reason ??
                    'The extension providing this view is not installed or currently disabled.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      workbench.closeView(contextData.viewId);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: const Text('Close View'),
                  ),
                  if (contextData.pluginId != null) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        commands.execute('alhambra.plugins.enablePlugin',
                            CommandContext(context: context));
                      },
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Enable Plugin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnavailableViewPlaceholder extends ConsumerWidget {
  final ViewPlaceholderContext contextData;

  const UnavailableViewPlaceholder({
    super.key,
    required this.contextData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edition = contextData.requiredEdition ?? 'Pro / Enterprise';
    final workbench = ref.watch(workbenchControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_outlined,
                  size: 36, color: AppTheme.accent),
              const SizedBox(height: 10),
              Text(
                contextData.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                contextData.reason ??
                    'This view requires an active $edition license.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      workbench.closeView(contextData.viewId);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: const Text('Close View'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Contact sales or administrator to upgrade to $edition.')),
                      );
                    },
                    icon: const Icon(Icons.upgrade, size: 14),
                    label: Text('Upgrade to $edition'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrokenViewPlaceholder extends StatefulWidget {
  final ViewPlaceholderContext contextData;

  const BrokenViewPlaceholder({
    super.key,
    required this.contextData,
  });

  @override
  State<BrokenViewPlaceholder> createState() => _BrokenViewPlaceholderState();
}

class _BrokenViewPlaceholderState extends State<BrokenViewPlaceholder> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF453A).withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 36, color: Color(0xFFFF453A)),
              const SizedBox(height: 10),
              Text(
                'View Crashed: ${widget.contextData.title}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFFF453A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'This view encountered an error while rendering.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.contextData.onRetry != null) ...[
                    ElevatedButton.icon(
                      onPressed: widget.contextData.onRetry,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Retry View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                    child: Text(
                      _showDetails
                          ? 'Hide technical details'
                          : 'Show technical details',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              if (_showDetails && widget.contextData.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.contextData.error.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

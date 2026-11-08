import 'package:flutter/material.dart';
import '../../theme/dimensions.dart';

enum AlhambraButtonVariant { primary, secondary, tonal, outlined, text }

/// Standard button component for Alhambra applications.
class AlhambraButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final AlhambraButtonVariant variant;
  final bool isLoading;

  const AlhambraButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = AlhambraButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        child,
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AlhambraDimensions.buttonHeight,
        minWidth: AlhambraDimensions.minTouchTarget,
      ),
      child: switch (variant) {
        AlhambraButtonVariant.primary => FilledButton(
            onPressed: effectiveOnPressed,
            child: content,
          ),
        AlhambraButtonVariant.secondary => FilledButton.tonal(
            onPressed: effectiveOnPressed,
            child: content,
          ),
        AlhambraButtonVariant.tonal => FilledButton.tonal(
            onPressed: effectiveOnPressed,
            child: content,
          ),
        AlhambraButtonVariant.outlined => OutlinedButton(
            onPressed: effectiveOnPressed,
            child: content,
          ),
        AlhambraButtonVariant.text => TextButton(
            onPressed: effectiveOnPressed,
            child: content,
          ),
      },
    );
  }
}

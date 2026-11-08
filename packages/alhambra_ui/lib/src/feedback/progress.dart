import 'package:flutter/material.dart';
import '../theme/spacing.dart';

/// Labeled progress indicator with support for both determinate and indeterminate modes.
class LabeledProgress extends StatelessWidget {
  final double? value;
  final String? label;

  const LabeledProgress({
    super.key,
    this.value,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AlhambraSpacing.xs),
        ],
        LinearProgressIndicator(value: value),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/spacing.dart';

/// Reusable card component for containers, dashboards, and summary panels.
class AlhambraCard extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AlhambraCard({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.all(AlhambraSpacing.md),
            child: header!,
          ),
          const Divider(height: 1),
        ],
        Padding(
          padding: padding ?? const EdgeInsets.all(AlhambraSpacing.md),
          child: child,
        ),
        if (footer != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AlhambraSpacing.md),
            child: footer!,
          ),
        ],
      ],
    );

    if (onTap != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );
  }
}

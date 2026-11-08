import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

/// Standard surface container adhering to the IDE elevation hierarchy
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool elevated;
  final Border? customBorder;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: elevated ? colors.surfaceElevated : colors.surface,
        border: customBorder ?? Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

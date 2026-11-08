import 'package:flutter/material.dart';
import '../theme/dimensions.dart';

/// Screen size category based on available width.
enum ScreenSize {
  /// Mobile phones / narrow views (< 600px).
  compact,

  /// Tablets / foldable displays / half screens (600px - 1024px).
  medium,

  /// Desktop / wide browser windows (>= 1024px).
  expanded;

  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
}

/// Helper and widget for responsive layouts adapting to [ScreenSize].
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize)? builder;
  final Widget? compact;
  final Widget? medium;
  final Widget? expanded;

  const ResponsiveLayout({
    super.key,
    this.builder,
    this.compact,
    this.medium,
    this.expanded,
  }) : assert(
          builder != null || compact != null || medium != null || expanded != null,
          'Either builder or at least one breakpoint widget must be provided',
        );

  /// Classifies the [ScreenSize] from the given [width] or [BuildContext].
  static ScreenSize classifyWidth(double width) {
    if (width < AlhambraDimensions.compactBreakpoint) {
      return ScreenSize.compact;
    } else if (width < AlhambraDimensions.mediumBreakpoint) {
      return ScreenSize.medium;
    } else {
      return ScreenSize.expanded;
    }
  }

  /// Classifies the [ScreenSize] from the given [context].
  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return classifyWidth(width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = classifyWidth(constraints.maxWidth);
        if (builder != null) {
          return builder!(context, screenSize);
        }

        return switch (screenSize) {
          ScreenSize.compact => compact ?? medium ?? expanded ?? const SizedBox.shrink(),
          ScreenSize.medium => medium ?? expanded ?? compact ?? const SizedBox.shrink(),
          ScreenSize.expanded => expanded ?? medium ?? compact ?? const SizedBox.shrink(),
        };
      },
    );
  }
}

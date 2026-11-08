/// Breakpoint thresholds and screen-class helpers for the Alhambra Platform.
///
/// All layout decisions are made from the **available widget constraints**
/// (via [LayoutBuilder]) rather than from device type or orientation. This
/// makes the layout correct in resizable windows, multi-window, and
/// picture-in-picture scenarios.
///
/// Breakpoints follow a conventional three-tier model:
///
///  |  Tier   | Width range         | Typical form factor                |
///  |---------|---------------------|------------------------------------|
///  | small   | < 600 dp            | Phone / narrow window              |
///  | medium  | 600–1024 dp         | Tablet / split-screen / landscape  |
///  | large   | ≥ 1024 dp           | Desktop / laptop / large tablet    |
library;

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Screen-class enum
// ---------------------------------------------------------------------------

/// Screen-size classification used by the platform layout system.
enum ScreenClass {
  /// Narrow layout — single-column, no sidebar panels visible.
  small,

  /// Intermediate layout — sidebar can slide in as a drawer.
  medium,

  /// Full workbench layout — sidebar, main area, bottom panel and secondary
  /// panel displayed simultaneously.
  large,
}

// ---------------------------------------------------------------------------
// Breakpoint constants
// ---------------------------------------------------------------------------

/// Platform-wide breakpoint constants.
///
/// Developers extending the platform should rely on the [ScreenClass] emitted
/// by [PlatformBreakpoints.classFor] to adapt their contributed plugin views
/// rather than hard-coding numeric widths.
///
/// ### Extension example
/// ```dart
/// LayoutBuilder(builder: (context, constraints) {
///   final screen = PlatformBreakpoints.classFor(constraints.maxWidth);
///   if (screen == ScreenClass.small) return _compactView();
///   return _fullView();
/// })
/// ```
abstract final class PlatformBreakpoints {
  /// Minimum width (dp) for the **medium** screen class.
  static const double mediumMinWidth = 600.0;

  /// Minimum width (dp) for the **large** screen class.
  static const double largeMinWidth = 1024.0;

  /// Classifies [width] into a [ScreenClass].
  static ScreenClass classFor(double width) {
    if (width >= largeMinWidth) return ScreenClass.large;
    if (width >= mediumMinWidth) return ScreenClass.medium;
    return ScreenClass.small;
  }

  /// Returns the [ScreenClass] by querying [MediaQuery] in [context].
  ///
  /// Prefer using a [LayoutBuilder] + [classFor] when you already have
  /// a [BoxConstraints] at hand — [MediaQuery.sizeOf] reports the full
  /// window size, not the local widget's allocated space.
  static ScreenClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return classFor(width);
  }
}

// ---------------------------------------------------------------------------
// InheritedWidget carrier (so deep descendants can read the screen class)
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that propagates the current [ScreenClass] down the
/// widget tree.
///
/// Placed by [GenericWorkbenchLayoutView] at the root of each layout variant
/// so that any contributed view can read the current screen class without
/// performing its own constraint check:
///
/// ```dart
/// final screen = PlatformScreenClass.of(context);
/// ```
class PlatformScreenClass extends InheritedWidget {
  const PlatformScreenClass({
    super.key,
    required this.screenClass,
    required super.child,
  });

  final ScreenClass screenClass;

  /// Returns the nearest [ScreenClass] in the widget tree.
  ///
  /// Falls back to [ScreenClass.large] when no ancestor is found (e.g., in
  /// tests that do not wrap with a workbench layout).
  static ScreenClass of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PlatformScreenClass>()
            ?.screenClass ??
        ScreenClass.large;
  }

  @override
  bool updateShouldNotify(PlatformScreenClass old) =>
      old.screenClass != screenClass;
}

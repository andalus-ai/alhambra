import 'ui_surface.dart';

class UiLocation {
  final String surface;
  final String slot;

  const UiLocation({
    required this.surface,
    required this.slot,
  });

  @override
  bool operator ==(Object other) {
    return other is UiLocation && other.surface == surface && other.slot == slot;
  }

  @override
  int get hashCode => Object.hash(surface, slot);

  @override
  String toString() => 'UiLocation($surface.$slot)';
}

abstract final class UiLocations {
  static const toolbarStart = UiLocation(
    surface: UiSurfaces.globalToolbar,
    slot: 'start',
  );

  static const toolbarCenter = UiLocation(
    surface: UiSurfaces.globalToolbar,
    slot: 'center',
  );

  static const toolbarEnd = UiLocation(
    surface: UiSurfaces.globalToolbar,
    slot: 'end',
  );

  static const statusBarStart = UiLocation(
    surface: UiSurfaces.statusBarLeft,
    slot: 'start',
  );

  static const statusBarCenter = UiLocation(
    surface: UiSurfaces.statusBarLeft,
    slot: 'center',
  );

  static const statusBarEnd = UiLocation(
    surface: UiSurfaces.statusBarRight,
    slot: 'end',
  );

  static const activityPrimary = UiLocation(
    surface: UiSurfaces.activityBar,
    slot: 'primary',
  );

  static const activitySecondary = UiLocation(
    surface: UiSurfaces.activityBar,
    slot: 'secondary',
  );

  static const activityBottom = UiLocation(
    surface: UiSurfaces.activityBar,
    slot: 'bottom',
  );
}

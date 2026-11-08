import 'dart:async';
import 'package:flutter/widgets.dart';
import '../extensions/placed_contribution.dart';
import '../ui/ui_location.dart';
import 'activity_bar_section.dart';

/// Callback function type for building activity badges.
typedef ActivityBadgeBuilder = Widget? Function(
  BuildContext context,
  String? activeActivityId,
);

/// Represents an activity bar contribution.
class ActivityBarContribution implements PlacedContribution {
  @override
  final String id;
  /// The ID of the owner.
  @override
  final String ownerId;

  /// The label for the contribution.
  final String label;
  /// The icon for the contribution.
  final IconData icon;
  /// The active icon for the contribution.
  final IconData? activeIcon;
  /// The section for the contribution.
  final ActivityBarSection section;

  @override
  final int order;

  /// The default view ID for the contribution.
  final String? defaultViewId;
  /// The action to perform when the contribution is activated.
  final FutureOr<void> Function(BuildContext context)? action;
  /// Whether the contribution is visible.
  final bool Function(String? activeActivityId)? isVisible;
  /// Whether the contribution is enabled.
  final bool Function(String? activeActivityId)? isEnabled;
  /// The badge builder for the contribution.
  final ActivityBadgeBuilder? badgeBuilder;

  @override
  UiLocation get location {
    switch (section) {
      case ActivityBarSection.primary:
        return UiLocations.activityPrimary;
      case ActivityBarSection.secondary:
        return UiLocations.activitySecondary;
      case ActivityBarSection.bottom:
        return UiLocations.activityBottom;
    }
  }

  const ActivityBarContribution({
    required this.id,
    required this.ownerId,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.section = ActivityBarSection.primary,
    this.order = 0,
    this.defaultViewId,
    this.action,
    this.isVisible,
    this.isEnabled,
    this.badgeBuilder,
  });
}

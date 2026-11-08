import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../activity_bar/activity_bar_registry.dart';
import '../views/view_registry.dart';

/// Validates contributions to the workbench.
class ContributionValidator {
  final ViewRegistry views;
  final ActivityBarRegistry activityBar;

  /// Creates a new [ContributionValidator].
  ContributionValidator({required this.views, required this.activityBar});

  /// Validates all contributions for the given owner.
  /// [ownerId] - The ID of the owner to validate contributions for.
  /// Throws [StateError] if any contributions are invalid.
  ///
  /// Example:
  /// ```dart
  /// final validator = ContributionValidator(
  ///   views: views,
  ///   activityBar: activityBar,
  /// );
  /// validator.validateOwner('my-plugin');
  /// ```
  void validateOwner(String ownerId) {
    final activities = activityBar.getAllForOwner(ownerId);
    for (final activity in activities) {
      if (activity.defaultViewId != null) {
        final view = views.get(activity.defaultViewId!);
        if (view == null) {
          throw StateError(
            'Activity "${activity.id}" references unknown view "${activity.defaultViewId}".',
          );
        }
      }
    }
  }
}

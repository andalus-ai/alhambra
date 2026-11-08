import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../views/view_registry.dart';
import 'view_location.dart';

/// Resolves the initial location for a view.
class WorkbenchLayoutResolver {
  /// The view registry.
  final ViewRegistry views;

  /// Creates a new [WorkbenchLayoutResolver].
  const WorkbenchLayoutResolver({required this.views});

  /// Resolves the initial location for a view.
  /// [viewId] - The ID of the view to resolve the initial location for.
  /// Returns a [ViewLocation] instance representing the initial location for the view.
  /// Throws [StateError] if the view is not found.
  ///
  /// Example:
  /// ```dart
  /// final location = resolver.resolveInitialLocation('explorer');
  /// ```
  ViewLocation resolveInitialLocation(String viewId) {
    final contribution = views.get(viewId);
    if (contribution == null) {
      throw StateError('Unknown view: $viewId');
    }

    return ViewLocation(
      viewId: viewId,
      area: contribution.preferredPlacement.preferredArea,
      groupId: contribution.preferredPlacement.groupId,
    );
  }

  /// Resolves a supported area for a view.
  /// [requested] - The requested area for the view.
  /// [supportedAreas] - The supported areas for the view.
  /// Returns a [ViewArea] instance representing the supported area for the view.
  ///
  /// Example:
  /// ```dart
  /// final area = resolver.resolveSupportedArea(ViewArea.left);
  /// ```
  ViewArea resolveSupportedArea(
    ViewArea requested, {
    Set<ViewArea>? supportedAreas,
  }) {
    final supported = supportedAreas ?? ViewArea.values.toSet();
    if (supported.contains(requested)) {
      return requested;
    }
    return ViewArea.main;
  }
}

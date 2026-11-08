import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/placed_contribution_registry.dart';

/// The activity bar registry is responsible for registering and managing
/// activity bar items.
///
/// It is used by the activity bar service to get the current context.
class ActivityBarRegistry
    extends PlacedContributionRegistry<ActivityBarContribution> {
  /// Resolves activity bar items for a given section.
  ///
  /// It is called by the activity bar service to get the current context.
  List<ActivityBarContribution> resolve(
    ActivityBarSection section, {
    String? activeActivityId,
  }) {
    final items = getAll()
        .where((item) => item.section == section)
        .where((item) => item.isVisible?.call(activeActivityId) ?? true)
        .toList();

    items.sort(ContributionOrdering.compare);
    return items;
  }

  /// Returns all primary activity bar items.
  ///
  /// It is called by the activity bar service to get the current context.
  List<ActivityBarContribution> get primaryItems =>
      resolve(ActivityBarSection.primary);

  /// Returns all secondary activity bar items.
  ///
  /// It is called by the activity bar service to get the current context.
  List<ActivityBarContribution> get secondaryItems =>
      resolve(ActivityBarSection.secondary);

  /// Returns all bottom activity bar items.
  ///
  /// It is called by the activity bar service to get the current context.
  List<ActivityBarContribution> get bottomItems =>
      resolve(ActivityBarSection.bottom);
}

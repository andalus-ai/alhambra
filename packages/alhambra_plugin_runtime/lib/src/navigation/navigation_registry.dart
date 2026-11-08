import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

/// The navigation registry is responsible for registering and managing
/// navigation items.
///
/// It is used by the navigation service to get the current context.
class NavigationRegistry extends ContributionRegistry<NavigationContribution> {
  final Map<String, NavigationGroup> _groups = {};

  /// Registers a new group.
  ///
  /// It is called by the navigation service to register a new group.
  void registerGroup(NavigationGroup group) {
    _groups[group.id] = group;
  }

  /// Unregisters a group by its ID.
  ///
  /// It is called by the navigation service to unregister a group.
  void unregisterGroup(String groupId) {
    _groups.remove(groupId);
  }

  /// Returns a group by its ID.
  ///
  /// It is called by the navigation service to get the current context.
  NavigationGroup? getGroup(String groupId) => _groups[groupId];

  /// Returns all available groups.
  ///
  /// It is called by the navigation service to get the current context.
  List<NavigationGroup> get groups {
    final list = _groups.values.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Returns all items for a given group.
  ///
  /// It is called by the navigation service to get the current context.
  List<NavigationContribution> itemsForGroup(String groupId) {
    final items = getAll().where((item) => item.groupId == groupId).toList();
    items.sort(ContributionOrdering.compare);
    return items;
  }
}

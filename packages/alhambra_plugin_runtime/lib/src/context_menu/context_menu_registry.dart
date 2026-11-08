import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

/// The context menu registry is responsible for registering and managing
/// context menu items.
///
/// It is used by the context menu service to get the current context.
class ContextMenuRegistry extends ContributionRegistry<MenuContribution> {
  /// Resolves context menu items for a given context.
  ///
  /// It is called by the context menu service to get the current context.
  List<MenuContribution> resolve(MenuContext context) {
    final items = getAll()
        .where((item) => item.targetId == context.targetId)
        .where((item) => item.isVisible?.call(context) ?? true)
        .toList();

    items.sort(ContributionOrdering.compare);
    return items;
  }
}

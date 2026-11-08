import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

class ViewRegistry extends ContributionRegistry<ViewContribution> {
  List<ViewContribution> forRegion(UiRegion region) {
    final items = getAll()
        .where((view) => view.defaultRegion == region)
        .toList();
    items.sort(ContributionOrdering.compare);
    return items;
  }

  List<ViewContribution> forArea(ViewArea area) {
    final items = getAll()
        .where((view) => view.preferredPlacement.preferredArea == area)
        .toList();
    items.sort(ContributionOrdering.compare);
    return items;
  }
}

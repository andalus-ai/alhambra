import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/placed_contribution_registry.dart';

class ToolbarRegistry extends PlacedContributionRegistry<ToolbarContribution> {
  List<ToolbarContribution> resolve(
    ToolbarContext context,
    ToolbarAlignment alignment,
  ) {
    final items = getAll()
        .where((item) => item.targetId == context.targetId)
        .where((item) => item.alignment == alignment)
        .where((item) => item.isVisible?.call(context) ?? true)
        .toList();

    items.sort(ContributionOrdering.compare);
    return items;
  }
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/placed_contribution_registry.dart';

class StatusBarRegistry
    extends PlacedContributionRegistry<StatusBarContribution> {
  List<StatusBarContribution> resolve(
    StatusBarContext context,
    StatusBarAlignment alignment,
  ) {
    final items = getAll()
        .where((item) => item.alignment == alignment)
        .where((item) => item.isVisible?.call(context) ?? true)
        .toList();

    items.sort(ContributionOrdering.compare);
    return items;
  }
}

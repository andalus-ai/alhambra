import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'contribution_registry.dart';

class PlacedContributionRegistry<T extends PlacedContribution>
    extends ContributionRegistry<T> {
  List<T> forLocation(UiLocation location) {
    final result = getAll().where((item) => item.location == location).toList();
    result.sort(ContributionOrdering.compare);
    return result;
  }
}

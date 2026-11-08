import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

class SettingsRegistry extends ContributionRegistry<SettingsPageContribution> {
  List<SettingsPageContribution> forSection(String section) {
    final items = getAll().where((page) => page.section == section).toList();
    items.sort(ContributionOrdering.compare);
    return items;
  }

  List<String> get sections =>
      getAll().map((page) => page.section).toSet().toList();
}

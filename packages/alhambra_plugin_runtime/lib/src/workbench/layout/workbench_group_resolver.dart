import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'view_group_id.dart';

abstract interface class ViewGroupIdGenerator {
  String next();
}

class RuntimeViewGroupIdGenerator implements ViewGroupIdGenerator {
  int _counter = 0;

  @override
  String next() {
    _counter++;
    return 'alhambra.group.runtime.$_counter';
  }
}

class WorkbenchGroupResolver {
  const WorkbenchGroupResolver();

  String defaultGroupFor(ViewArea area) {
    return switch (area) {
      ViewArea.sidebar => CoreViewGroups.sidebar,
      ViewArea.main => CoreViewGroups.main,
      ViewArea.bottomPanel => CoreViewGroups.bottom,
      ViewArea.secondaryPanel => CoreViewGroups.secondary,
    };
  }
}

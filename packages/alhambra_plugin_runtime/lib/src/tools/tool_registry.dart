import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_registry.dart';

class ToolRegistry extends ContributionRegistry<AgentTool> {
  AgentTool? findByName(String name) => get(name);

  List<AgentTool> get availableTools => getAll();
}

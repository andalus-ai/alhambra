import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_graph.dart';

class CompositionPlan {
  final List<CompositionNode> activationOrder;
  final Map<String, CompositionNode> nodes;

  const CompositionPlan({required this.activationOrder, required this.nodes});

  static CompositionPlan fromGraph(CompositionGraph graph) {
    final order = graph.topologicalSort();
    return CompositionPlan(activationOrder: order, nodes: graph.nodes);
  }
}

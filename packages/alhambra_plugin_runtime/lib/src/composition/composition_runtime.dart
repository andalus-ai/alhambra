import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_graph.dart';
import 'composition_plan.dart';
import 'composition_transaction.dart';

abstract interface class CompositionRuntime {
  CompositionGraph get graph;
  CompositionTransaction beginTransaction({
    void Function(CompositionPlan plan)? onCommit,
  });
  void deactivateOwner(String ownerId, [DeactivationStrategy strategy]);
}

class DefaultCompositionRuntime implements CompositionRuntime {
  final CompositionGraph _liveGraph = CompositionGraph();
  final void Function(String ownerId)? onOwnerDeactivated;

  DefaultCompositionRuntime({this.onOwnerDeactivated});

  @override
  CompositionGraph get graph => _liveGraph;

  @override
  CompositionTransaction beginTransaction({
    void Function(CompositionPlan plan)? onCommit,
  }) {
    return DefaultCompositionTransaction(
      liveGraph: _liveGraph,
      onCommit: (plan) {
        if (onCommit != null) {
          onCommit(plan);
        }
      },
    );
  }

  @override
  void deactivateOwner(
    String ownerId, [
    DeactivationStrategy strategy = DeactivationStrategy.degrade,
  ]) {
    final nodesToRemove = _liveGraph.nodes.values
        .where((n) => n.ownerId == ownerId)
        .map((n) => n.id)
        .toList();

    for (final id in nodesToRemove) {
      _liveGraph.remove(id);
    }

    if (onOwnerDeactivated != null) {
      onOwnerDeactivated!(ownerId);
    }
  }
}

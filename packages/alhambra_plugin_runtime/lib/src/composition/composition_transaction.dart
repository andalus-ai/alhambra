import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_graph.dart';
import 'composition_plan.dart';

abstract interface class CompositionTransaction {
  void stage(CompositionNode node);
  void stageAll(Iterable<CompositionNode> nodes);
  CompositionResult commit();
  void rollback();
  bool get isCommitted;
  bool get isRolledBack;
}

class DefaultCompositionTransaction implements CompositionTransaction {
  final CompositionGraph liveGraph;
  final void Function(CompositionPlan plan) onCommit;
  final CompositionGraph _stagedGraph = CompositionGraph();
  bool _committed = false;
  bool _rolledBack = false;

  DefaultCompositionTransaction({
    required this.liveGraph,
    required this.onCommit,
  });

  @override
  bool get isCommitted => _committed;

  @override
  bool get isRolledBack => _rolledBack;

  @override
  void stage(CompositionNode node) {
    if (_committed || _rolledBack) {
      throw StateError('Transaction is already completed');
    }
    _stagedGraph.add(node);
  }

  @override
  void stageAll(Iterable<CompositionNode> nodes) {
    for (final node in nodes) {
      stage(node);
    }
  }

  @override
  CompositionResult commit() {
    if (_committed) throw StateError('Transaction already committed');
    if (_rolledBack) throw StateError('Transaction has been rolled back');

    // Validate staged graph against both staged nodes and existing live nodes
    final diagnostics = _stagedGraph.validate(
      knownExternalNodeIds: liveGraph.nodes.keys.toSet(),
    );

    if (diagnostics.isNotEmpty) {
      rollback();
      return CompositionFailure(diagnostics: diagnostics);
    }

    final plan = CompositionPlan.fromGraph(_stagedGraph);
    liveGraph.addAll(_stagedGraph.nodes.values);
    onCommit(plan);
    _committed = true;

    return CompositionSuccess(
      activatedNodeIds: plan.activationOrder.map((n) => n.id).toList(),
    );
  }

  @override
  void rollback() {
    _rolledBack = true;
  }
}

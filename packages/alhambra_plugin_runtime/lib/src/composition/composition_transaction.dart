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
    _ensureOpen();
    _stagedGraph.add(node);
  }

  @override
  void stageAll(Iterable<CompositionNode> nodes) {
    _ensureOpen();
    final candidate = CompositionGraph();
    candidate.addAll(_stagedGraph.nodes.values);
    candidate.addAll(nodes);
    for (final id in _stagedGraph.nodes.keys.toList()) {
      _stagedGraph.remove(id);
    }
    _stagedGraph.addAll(candidate.nodes.values);
  }

  @override
  CompositionResult commit() {
    _ensureOpen();

    final candidate = CompositionGraph();
    try {
      candidate.addAll(liveGraph.nodes.values);
      candidate.addAll(_stagedGraph.nodes.values);
    } on ArgumentError catch (error) {
      rollback();
      return CompositionFailure(diagnostics: [
        DuplicateNodeDiagnostic(
          nodeId: _duplicateId(error),
          existingOwnerId: 'live graph',
          newOwnerId: 'staged graph',
        ),
      ]);
    }

    final diagnostics = candidate.validate();
    if (diagnostics.isNotEmpty) {
      rollback();
      return CompositionFailure(diagnostics: diagnostics);
    }

    final plan = CompositionPlan.fromGraph(candidate);
    // Validation and plan construction precede the first live mutation.
    liveGraph.addAll(_stagedGraph.nodes.values);
    onCommit(plan);
    _committed = true;

    return CompositionSuccess(
      activatedNodeIds: plan.activationOrder
          .where((node) => _stagedGraph.nodes.containsKey(node.id))
          .map((node) => node.id)
          .toList(),
    );
  }

  @override
  void rollback() {
    if (_committed) throw StateError('Cannot roll back a committed transaction');
    if (_rolledBack) return;
    _rolledBack = true;
  }

  void _ensureOpen() {
    if (_committed || _rolledBack) {
      throw StateError('Transaction is already completed');
    }
  }

  String _duplicateId(ArgumentError error) {
    final value = error.invalidValue;
    return value is String ? value : 'unknown';
  }
}

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
  List<CompositionNode> get stagedNodes;
}

class DefaultCompositionTransaction implements CompositionTransaction {
  final CompositionGraph liveGraph;
  final void Function(CompositionPlan plan) onCommit;
  final CompositionLifecycle? lifecycle;
  final CompositionGraph _stagedGraph = CompositionGraph();
  bool _committed = false;
  bool _rolledBack = false;

  DefaultCompositionTransaction({
    required this.liveGraph,
    required this.onCommit,
    this.lifecycle,
  });

  @override
  bool get isCommitted => _committed;

  @override
  List<CompositionNode> get stagedNodes =>
      List.unmodifiable(_stagedGraph.nodes.values);

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
    final candidate = CompositionGraph()..addAll(_stagedGraph.nodes.values);
    candidate.addAll(nodes);
    final replacement = candidate.nodes.values.toList(growable: false);
    for (final id in _stagedGraph.nodes.keys.toList()) {
      _stagedGraph.remove(id);
    }
    _stagedGraph.addAll(replacement);
  }

  @override
  CompositionResult commit() {
    _ensureOpen();

    // Detect conflicts explicitly so diagnostics retain the actual owners.
    final liveNodes = liveGraph.nodes;
    for (final staged in _stagedGraph.nodes.values) {
      final existing = liveNodes[staged.id];
      if (existing != null) {
        rollback();
        return CompositionFailure(diagnostics: [
          DuplicateNodeDiagnostic(
            nodeId: staged.id,
            existingOwnerId: existing.ownerId,
            newOwnerId: staged.ownerId,
          ),
        ]);
      }
    }

    final candidate = CompositionGraph()..addAll(liveNodes.values);
    candidate.addAll(_stagedGraph.nodes.values);
    final diagnostics = candidate.validate();
    if (diagnostics.isNotEmpty) {
      rollback();
      return CompositionFailure(diagnostics: diagnostics);
    }

    // Plan construction is deliberately before publication: a planning
    // failure cannot leave any staged node in the live graph.
    final plan = CompositionPlan.fromGraph(candidate);
    final stagedIds = _stagedGraph.nodes.keys.toList(growable: false);

    // Preparation runs before publication so validation/setup failures cannot
    // expose partially activated contributions.
    try {
      lifecycle?.prepare(plan.activationOrder);
    } catch (error, stackTrace) {
      _compensateAfterFailure(plan.activationOrder, error, stackTrace);
      _rolledBack = true;
      Error.throwWithStackTrace(error, stackTrace);
    }

    // addAll itself is atomic. Activation runs after publication so lifecycle
    // implementations can resolve dependencies from the live graph.
    liveGraph.addAll(_stagedGraph.nodes.values);
    try {
      lifecycle?.activate(plan.activationOrder);
      onCommit(plan); // Backward-compatible activation hook.
    } catch (error, stackTrace) {
      for (final id in stagedIds) {
        liveGraph.remove(id);
      }
      _compensateAfterFailure(plan.activationOrder, error, stackTrace);
      _rolledBack = true;
      Error.throwWithStackTrace(error, stackTrace);
    }

    _committed = true;
    return CompositionSuccess(
      activatedNodeIds: plan.activationOrder
          .where((node) => _stagedGraph.nodes.containsKey(node.id))
          .map((node) => node.id)
          .toList(growable: false),
    );
  }

  @override
  void rollback() {
    if (_committed) throw StateError('Cannot roll back a committed transaction');
    if (_rolledBack) return;
    _rolledBack = true;
  }

  void _compensateAfterFailure(
    List<CompositionNode> orderedNodes,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      lifecycle?.compensate(orderedNodes, error, stackTrace);
    } catch (_) {
      // Preserve the original lifecycle failure. Compensation is best-effort;
      // implementations should report their own compensation failures.
    }
  }

  void _ensureOpen() {
    if (_committed || _rolledBack) {
      throw StateError('Transaction is already completed');
    }
  }
}

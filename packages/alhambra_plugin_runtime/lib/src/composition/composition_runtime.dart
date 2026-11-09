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

  /// Deactivates every composition node contributed by [ownerId].
  ///
  /// [DeactivationStrategy.reject] leaves the graph untouched and throws when
  /// any remaining node (including one with an optional dependency) refers to
  /// an owned node. [DeactivationStrategy.cascade] removes all transitive
  /// dependents. [DeactivationStrategy.degrade] removes only transitive
  /// dependents whose dependency on a removed node is required; optional-only
  /// consumers remain registered and may resolve the missing capability at
  /// runtime.
  @override
  void deactivateOwner(
    String ownerId, [
    DeactivationStrategy strategy = DeactivationStrategy.degrade,
  ]) {
    final ownedIds = _liveGraph.nodes.values
        .where((node) => node.ownerId == ownerId)
        .map((node) => node.id)
        .toSet();

    if (ownedIds.isEmpty) return;

    final nodes = _liveGraph.nodes;
    final removalIds = <String>{...ownedIds};
    final dependents = <String, List<CompositionNode>>{};
    for (final node in nodes.values) {
      for (final dependency in node.dependencies) {
        dependents.putIfAbsent(dependency.nodeId, () => []).add(node);
      }
    }

    if (strategy == DeactivationStrategy.reject) {
      final blockers = <String>{};
      for (final id in ownedIds) {
        for (final dependent in dependents[id] ?? const <CompositionNode>[]) {
          if (!ownedIds.contains(dependent.id)) blockers.add(dependent.id);
        }
      }
      if (blockers.isNotEmpty) {
        final ordered = blockers.toList()..sort();
        throw StateError(
          'Cannot deactivate owner "$ownerId": dependent nodes remain: '
          '${ordered.join(', ')}.',
        );
      }
    } else {
      final pending = <String>[...ownedIds]..sort();
      while (pending.isNotEmpty) {
        final removedId = pending.removeAt(0);
        for (final dependent in dependents[removedId] ?? const <CompositionNode>[]) {
          if (removalIds.contains(dependent.id)) continue;
          final shouldRemove = strategy == DeactivationStrategy.cascade ||
              dependent.dependencies.any(
                (dependency) =>
                    dependency.nodeId == removedId && dependency.required,
              );
          if (shouldRemove) {
            removalIds.add(dependent.id);
            pending.add(dependent.id);
          }
        }
      }
    }

    // Compute the full set before mutating the live graph. Removing consumers
    // before providers keeps the operation's observable order predictable.
    final removalOrder = removalIds.toList()..sort();
    for (final id in removalOrder) {
      _liveGraph.remove(id);
    }

    onOwnerDeactivated?.call(ownerId);
  }
}

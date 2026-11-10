import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_graph.dart';
import 'composition_plan.dart';
import 'composition_transaction.dart';

abstract interface class CompositionRuntime {
  CompositionGraph get graph;
  CompositionTransaction beginTransaction({
    void Function(CompositionPlan plan)? onCommit,
    CompositionLifecycle? lifecycle,
    String? correlationId,
    CompositionLifecycleEventSink? onLifecycleEvent,
  });
  void deactivateOwner(String ownerId, [DeactivationStrategy strategy]);
}

class DefaultCompositionRuntime implements CompositionRuntime {
  final CompositionGraph _liveGraph = CompositionGraph();
  final void Function(String ownerId)? onOwnerDeactivated;
  final Map<String, CompositionLifecycle> _ownerLifecycles = {};
  final CompositionLifecycleEventSink? onLifecycleEvent;
  int _nextTransactionSequence = 0;

  DefaultCompositionRuntime({this.onOwnerDeactivated, this.onLifecycleEvent});

  @override
  CompositionGraph get graph => _liveGraph;

  @override
  CompositionTransaction beginTransaction({
    void Function(CompositionPlan plan)? onCommit,
    CompositionLifecycle? lifecycle,
    String? correlationId,
    CompositionLifecycleEventSink? onLifecycleEvent,
  }) {
    late final DefaultCompositionTransaction transaction;
    transaction = DefaultCompositionTransaction(
      liveGraph: _liveGraph,
      onCommit: (plan) {
        if (onCommit != null) {
          onCommit(plan);
        }
        if (lifecycle != null) {
          for (final node in transaction.stagedNodes) {
            _ownerLifecycles.putIfAbsent(node.ownerId, () => lifecycle);
          }
        }
      },
      lifecycle: lifecycle,
      correlationId: correlationId ?? 'composition-${++_nextTransactionSequence}',
      onLifecycleEvent: onLifecycleEvent ?? this.onLifecycleEvent,
    );
    return transaction;
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
    final originalNodes = Map<String, CompositionNode>.from(nodes);
    final removalOrder = _liveGraph
        .topologicalSort()
        .map((node) => node.id)
        .where(removalIds.contains)
        .toList()
        .reversed
        .toList();

    // Preserve consumer-before-provider order across owners. Sorting owner IDs
    // here would make callback order unrelated to dependency order.
    final affectedOwners = <String>[];
    final seenOwners = <String>{};
    for (final id in removalOrder) {
      final ownerId = nodes[id]!.ownerId;
      if (seenOwners.add(ownerId)) affectedOwners.add(ownerId);
    }

    final lifecycleNodes = <String, List<CompositionNode>>{};
    for (final id in removalOrder) {
      final node = nodes[id]!;
      lifecycleNodes.putIfAbsent(node.ownerId, () => []).add(node);
    }

    final deactivationCorrelationId = 'composition-deactivation-${++_nextTransactionSequence}';
    try {
      // Remove graph entries first so deactivation hooks observe the new
      // graph. Nodes are supplied in consumer-before-provider order.
      for (final id in removalOrder) {
        _liveGraph.remove(id);
      }

      for (final affectedOwner in affectedOwners) {
        final lifecycle = _ownerLifecycles[affectedOwner];
        final ownedNodes = lifecycleNodes[affectedOwner];
        if (lifecycle != null && ownedNodes != null) {
          _runLifecycleHook(deactivationCorrelationId, CompositionLifecycleOperation.deactivate, ownedNodes, () => lifecycle.deactivate(ownedNodes));
        }
        onOwnerDeactivated?.call(affectedOwner);
      }
      for (final affectedOwner in affectedOwners) {
        final stillRegistered = _liveGraph.nodes.values.any(
          (node) => node.ownerId == affectedOwner,
        );
        if (!stillRegistered) _ownerLifecycles.remove(affectedOwner);
      }
    } catch (error, stackTrace) {
      for (final entry in lifecycleNodes.entries) {
        final lifecycle = _ownerLifecycles[entry.key];
        if (lifecycle == null) continue;
        try {
          _runLifecycleHook(deactivationCorrelationId, CompositionLifecycleOperation.compensate, entry.value, () => lifecycle.compensate(entry.value, error, stackTrace));
        } catch (_) {
          // Preserve the original deactivation error.
        }
      }
      // Keep the graph atomic if a lifecycle callback fails. Callback side
      // effects outside this graph are the callback implementer's
      // responsibility and cannot be compensated by this runtime.
      for (final id in _liveGraph.nodes.keys.toList()) {
        _liveGraph.remove(id);
      }
      _liveGraph.addAll(originalNodes.values);
      rethrow;
    }
  }
  void _runLifecycleHook(
    String correlationId,
    CompositionLifecycleOperation operation,
    List<CompositionNode> nodes,
    void Function() callback,
  ) {
    final sink = onLifecycleEvent;
    final nodeIds = nodes.map((node) => node.id).toList(growable: false);
    final ownerIds = nodes.map((node) => node.ownerId).toSet().toList()..sort();
    final stopwatch = Stopwatch()..start();
    _emitLifecycleEvent(sink, CompositionLifecycleEvent(
      correlationId: correlationId,
      operation: operation,
      status: CompositionLifecycleStatus.started,
      timestamp: DateTime.now().toUtc(),
      nodeIds: nodeIds,
      ownerIds: ownerIds,
    ));
    try {
      callback();
      stopwatch.stop();
      _emitLifecycleEvent(sink, CompositionLifecycleEvent(
        correlationId: correlationId,
        operation: operation,
        status: CompositionLifecycleStatus.succeeded,
        timestamp: DateTime.now().toUtc(),
        nodeIds: nodeIds,
        ownerIds: ownerIds,
        duration: stopwatch.elapsed,
      ));
    } catch (error) {
      stopwatch.stop();
      _emitLifecycleEvent(sink, CompositionLifecycleEvent(
        correlationId: correlationId,
        operation: operation,
        status: CompositionLifecycleStatus.failed,
        timestamp: DateTime.now().toUtc(),
        nodeIds: nodeIds,
        ownerIds: ownerIds,
        duration: stopwatch.elapsed,
        errorType: error.runtimeType.toString(),
        errorMessage: error.toString(),
      ));
      rethrow;
    }
  }

  void _emitLifecycleEvent(
    CompositionLifecycleEventSink? sink,
    CompositionLifecycleEvent event,
  ) {
    if (sink == null) return;
    try {
      sink(event);
    } catch (_) {
      // Diagnostics must not alter graph or lifecycle semantics.
    }
  }

}

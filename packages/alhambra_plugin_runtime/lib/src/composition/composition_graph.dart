import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Mutable composition graph. Validation and ordering are deterministic.
class CompositionGraph {
  final Map<String, CompositionNode> _nodes = {};

  Map<String, CompositionNode> get nodes => Map.unmodifiable(_nodes);

  /// Adds a node without silently replacing an existing contribution.
  void add(CompositionNode node) {
    final existing = _nodes[node.id];
    if (existing != null) {
      throw ArgumentError.value(
        node.id,
        'node.id',
        'Already registered by owner "${existing.ownerId}".',
      );
    }
    _nodes[node.id] = node;
  }

  /// Adds nodes atomically. Duplicate IDs leave this graph unchanged.
  void addAll(Iterable<CompositionNode> nodes) {
    final candidate = Map<String, CompositionNode>.from(_nodes);
    for (final node in nodes) {
      final existing = candidate[node.id];
      if (existing != null) {
        throw ArgumentError.value(
          node.id,
          'node.id',
          'Duplicate composition node (owners: "${existing.ownerId}" and "${node.ownerId}").',
        );
      }
      candidate[node.id] = node;
    }
    _nodes
      ..clear()
      ..addAll(candidate);
  }

  void remove(String nodeId) => _nodes.remove(nodeId);

  /// Validates required dependencies and reports every distinct cycle.
  List<CompositionDiagnostic> validate({
    Set<String> knownExternalNodeIds = const {},
  }) {
    final diagnostics = <CompositionDiagnostic>[];
    final known = {..._nodes.keys, ...knownExternalNodeIds};

    final ids = _nodes.keys.toList()..sort();
    for (final id in ids) {
      final node = _nodes[id]!;
      final dependencies = node.dependencies.toList()
        ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
      for (final dependency in dependencies) {
        if (dependency.required && !known.contains(dependency.nodeId)) {
          diagnostics.add(MissingDependencyDiagnostic(
            nodeId: node.id,
            dependencyId: dependency.nodeId,
          ));
        }
      }
    }

    // Three-color DFS. Continue after a back edge so independent cycles are found.
    final color = <String, int>{};
    final stack = <String>[];
    final cycleKeys = <String>{};

    void visit(String id) {
      color[id] = 1;
      stack.add(id);
      final node = _nodes[id];
      if (node != null) {
        final dependencies = node.dependencies.toList()
          ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
        for (final dependency in dependencies) {
          final target = dependency.nodeId;
          if (!_nodes.containsKey(target)) continue;
          final state = color[target] ?? 0;
          if (state == 0) {
            visit(target);
          } else if (state == 1) {
            final start = stack.indexOf(target);
            final cycle = [...stack.sublist(start), target];
            final canonical = _canonicalCycle(cycle);
            final key = canonical.join('|');
            if (cycleKeys.add(key)) {
              diagnostics.add(CompositionCycleDiagnostic(canonical));
            }
          }
        }
      }
      stack.removeLast();
      color[id] = 2;
    }

    for (final id in ids) {
      if ((color[id] ?? 0) == 0) visit(id);
    }
    return diagnostics;
  }

  /// Dependency-first order; ties are phase, then node ID.
  ///
  /// Throws [StateError] when the graph contains a cycle. Call [validate] first
  /// when diagnostics rather than an exception are desired.
  List<CompositionNode> topologicalSort() {
    final result = <CompositionNode>[];
    final state = <String, int>{};
    final ids = _nodes.keys.toList()
      ..sort((a, b) {
        final phase = _nodes[a]!.phase.index.compareTo(_nodes[b]!.phase.index);
        return phase != 0 ? phase : a.compareTo(b);
      });

    void visit(String id) {
      final current = state[id] ?? 0;
      if (current == 2) return;
      if (current == 1) {
        throw StateError('Composition graph contains a cycle at "$id".');
      }
      state[id] = 1;
      final node = _nodes[id]!;
      final dependencies = node.dependencies.toList()
        ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
      for (final dependency in dependencies) {
        if (_nodes.containsKey(dependency.nodeId)) visit(dependency.nodeId);
      }
      state[id] = 2;
      result.add(node);
    }

    for (final id in ids) {
      visit(id);
    }
    return result;
  }

  List<String> _canonicalCycle(List<String> cycle) {
    if (cycle.length < 2) return cycle;
    final ring = cycle.sublist(0, cycle.length - 1);
    if (ring.isEmpty) return cycle;
    var smallest = 0;
    for (var i = 1; i < ring.length; i++) {
      if (ring[i].compareTo(ring[smallest]) < 0) smallest = i;
    }
    final rotated = [...ring.sublist(smallest), ...ring.sublist(0, smallest)];
    return [...rotated, rotated.first];
  }
}

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class CompositionGraph {
  final Map<String, CompositionNode> _nodes = {};

  Map<String, CompositionNode> get nodes => Map.unmodifiable(_nodes);

  void add(CompositionNode node) {
    _nodes[node.id] = node;
  }

  void addAll(Iterable<CompositionNode> nodes) {
    for (final n in nodes) {
      _nodes[n.id] = n;
    }
  }

  void remove(String nodeId) {
    _nodes.remove(nodeId);
  }

  /// Validates the graph, checking for missing required dependencies and circular dependencies.
  List<CompositionDiagnostic> validate({
    Set<String> knownExternalNodeIds = const {},
  }) {
    final diagnostics = <CompositionDiagnostic>[];
    final allKnownIds = {..._nodes.keys, ...knownExternalNodeIds};

    // 1. Check for missing dependencies
    for (final node in _nodes.values) {
      for (final dep in node.dependencies) {
        if (dep.required && !allKnownIds.contains(dep.nodeId)) {
          diagnostics.add(
            MissingDependencyDiagnostic(
              nodeId: node.id,
              dependencyId: dep.nodeId,
            ),
          );
        }
      }
    }

    // 2. Check for dependency cycles using DFS
    final visited = <String, int>{}; // 0 = unvisited, 1 = visiting, 2 = visited
    final path = <String>[];

    bool hasCycle(String nodeId) {
      visited[nodeId] = 1;
      path.add(nodeId);

      final node = _nodes[nodeId];
      if (node != null) {
        for (final dep in node.dependencies) {
          if (_nodes.containsKey(dep.nodeId)) {
            final state = visited[dep.nodeId] ?? 0;
            if (state == 1) {
              // Found cycle
              final cycleStart = path.indexOf(dep.nodeId);
              final cyclePath = [...path.sublist(cycleStart), dep.nodeId];
              diagnostics.add(CompositionCycleDiagnostic(cyclePath));
              return true;
            } else if (state == 0) {
              if (hasCycle(dep.nodeId)) return true;
            }
          }
        }
      }

      path.removeLast();
      visited[nodeId] = 2;
      return false;
    }

    for (final nodeId in _nodes.keys) {
      if ((visited[nodeId] ?? 0) == 0) {
        hasCycle(nodeId);
      }
    }

    return diagnostics;
  }

  /// Produces topological activation order.
  List<CompositionNode> topologicalSort() {
    final sorted = <CompositionNode>[];
    final visited = <String>{};

    void visit(CompositionNode node) {
      if (visited.contains(node.id)) return;
      visited.add(node.id);

      for (final dep in node.dependencies) {
        final target = _nodes[dep.nodeId];
        if (target != null) {
          visit(target);
        }
      }

      sorted.add(node);
    }

    // Group nodes by phase first (bootstrap -> services -> commands -> views -> surfaces -> runtime)
    final phases = CompositionPhase.values;
    for (final phase in phases) {
      final phaseNodes = _nodes.values.where((n) => n.phase == phase);
      for (final n in phaseNodes) {
        visit(n);
      }
    }

    return sorted;
  }
}

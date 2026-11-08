import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class ContributionOrderingCycleException implements Exception {
  final List<String> cyclePath;
  const ContributionOrderingCycleException(this.cyclePath);

  @override
  String toString() =>
      'ContributionOrderingCycleException: Cycle in contribution ordering: ${cyclePath.join(' -> ')}';
}

/// Helper item for relational sorting.
final class SorterItem<T> {
  final String id;
  final T data;
  final ContributionOrderHint hint;

  const SorterItem({
    required this.id,
    required this.data,
    this.hint = const ContributionOrderHint(),
  });
}

/// Sorter that evaluates relational `before` and `after` constraints deterministically.
class RelationalContributionSorter {
  static List<T> sort<T>(List<SorterItem<T>> items) {
    if (items.isEmpty) return const [];

    final itemMap = {for (final item in items) item.id: item};
    final graph = <String, Set<String>>{};
    for (final item in items) {
      graph[item.id] = <String>{};
    }

    for (final item in items) {
      // If item has 'before: X', then item must come BEFORE X (X depends on item)
      if (item.hint.before != null &&
          itemMap.containsKey(item.hint.before!.value)) {
        graph[item.hint.before!.value]?.add(item.id);
      }
      // If item has 'after: Y', then item depends on Y (Y comes BEFORE item)
      if (item.hint.after != null &&
          itemMap.containsKey(item.hint.after!.value)) {
        graph[item.id]?.add(item.hint.after!.value);
      }
    }

    // Topological sort with cycle detection
    final visited = <String>{};
    final visiting = <String>{};
    final stack = <String>[];
    final sortedIds = <String>[];

    void dfs(String id) {
      if (visited.contains(id)) return;
      visiting.add(id);
      stack.add(id);

      final deps = graph[id] ?? {};
      final sortedDeps = deps.toList()..sort();
      for (final dep in sortedDeps) {
        if (visiting.contains(dep)) {
          final cycleIdx = stack.indexOf(dep);
          final cycleChain = [...stack.sublist(cycleIdx), dep];
          throw ContributionOrderingCycleException(cycleChain);
        }
        if (!visited.contains(dep)) {
          dfs(dep);
        }
      }

      stack.removeLast();
      visiting.remove(id);
      visited.add(id);
      sortedIds.add(id);
    }

    final allSortedIds = items.map((i) => i.id).toList()..sort();
    for (final id in allSortedIds) {
      if (!visited.contains(id)) {
        dfs(id);
      }
    }

    return sortedIds.map((id) => itemMap[id]!.data).toList();
  }
}

/// Token representing an active contribution lease.
class DefaultContributionLease implements ContributionLease {
  @override
  final ContributionId contributionId;
  final void Function() _onDispose;
  bool _disposed = false;

  DefaultContributionLease(this.contributionId, this._onDispose);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose();
  }
}

/// Registry managing extension UI contributions.
class DefaultExtensionContributionRegistry {
  final Map<String, ExtensionUiContribution> _contributions = {};

  ContributionLease register(ExtensionUiContribution contribution) {
    _contributions[contribution.id.value] = contribution;
    return DefaultContributionLease(contribution.id, () {
      _contributions.remove(contribution.id.value);
    });
  }

  void unregister(ContributionId id) {
    _contributions.remove(id.value);
  }

  ExtensionUiContribution? find(ContributionId id) => _contributions[id.value];
  Iterable<ExtensionUiContribution> get all => _contributions.values;

  void clear() => _contributions.clear();
}

/// Tracks contributions scoped to plugin or view lifetimes.
class ScopedContributionManager {
  final DefaultExtensionContributionRegistry registry;
  final Map<String, List<ContributionLease>> _leasesByScopeId = {};

  ScopedContributionManager({required this.registry});

  ContributionLease registerInScope(
    String scopeId,
    ExtensionUiContribution contribution,
  ) {
    final lease = registry.register(contribution);
    _leasesByScopeId.putIfAbsent(scopeId, () => []).add(lease);
    return lease;
  }

  void disposeScope(String scopeId) {
    final leases = _leasesByScopeId.remove(scopeId);
    if (leases != null) {
      for (final lease in leases) {
        lease.dispose();
      }
    }
  }
}

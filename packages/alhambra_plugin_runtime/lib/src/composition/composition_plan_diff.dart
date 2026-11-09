import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_plan.dart';

/// A deterministic difference between two composition plans.
final class CompositionPlanDiff {
  final List<CompositionNode> unchanged;
  final List<CompositionNode> added;
  final List<CompositionNode> removed;
  final List<CompositionNode> replaced;

  const CompositionPlanDiff({
    required this.unchanged,
    required this.added,
    required this.removed,
    required this.replaced,
  });

  bool get isEmpty =>
      added.isEmpty && removed.isEmpty && replaced.isEmpty;

  static CompositionPlanDiff between(
    CompositionPlan previous,
    CompositionPlan next,
  ) {
    final added = <String>{};
    final removed = <String>{};
    final replaced = <String>{};
    final unchanged = <String>{};

    for (final id in previous.nodes.keys) {
      final before = previous.nodes[id]!;
      final after = next.nodes[id];
      if (after == null) {
        removed.add(id);
      } else if (_sameDefinition(before, after)) {
        unchanged.add(id);
      } else {
        replaced.add(id);
      }
    }
    for (final id in next.nodes.keys) {
      if (!previous.nodes.containsKey(id)) added.add(id);
    }

    return CompositionPlanDiff(
      unchanged: next.activationOrder
          .where((node) => unchanged.contains(node.id))
          .toList(growable: false),
      added: next.activationOrder
          .where((node) => added.contains(node.id))
          .toList(growable: false),
      removed: previous.activationOrder.reversed
          .where((node) => removed.contains(node.id))
          .toList(growable: false),
      replaced: next.activationOrder
          .where((node) => replaced.contains(node.id))
          .toList(growable: false),
    );
  }

  static bool _sameDefinition(CompositionNode a, CompositionNode b) {
    if (a.runtimeType != b.runtimeType ||
        a.id != b.id ||
        a.ownerId != b.ownerId ||
        a.phase != b.phase ||
        !_sameDependencies(a.dependencies, b.dependencies)) {
      return false;
    }

    return switch ((a, b)) {
      (CommandNode left, CommandNode right) =>
        left.commandId == right.commandId,
      (ViewNode left, ViewNode right) => left.viewId == right.viewId,
      (UiContributionNode left, UiContributionNode right) =>
        left.contributionId == right.contributionId &&
            left.surfaceId == right.surfaceId,
      (ServiceNode left, ServiceNode right) =>
        left.serviceId == right.serviceId,
      (ShellRegionNode left, ShellRegionNode right) =>
        left.regionId == right.regionId,
      _ => false,
    };
  }

  static bool _sameDependencies(
    Set<CompositionDependency> a,
    Set<CompositionDependency> b,
  ) {
    if (a.length != b.length) return false;
    final left = a.map((d) => '${d.nodeId}:${d.required}').toList()..sort();
    final right = b.map((d) => '${d.nodeId}:${d.required}').toList()..sort();
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}

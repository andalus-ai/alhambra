import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_plan.dart';

/// Describes composition nodes whose owning plugins are not currently present.
class CompositionCompatibilityReport {
  final Set<String> unavailableOwnerIds;
  final Set<String> unavailableNodeIds;
  final Set<String> blockedRequiredNodeIds;
  final Set<String> optionalDependencyWarnings;

  CompositionCompatibilityReport({
    required Set<String> unavailableOwnerIds,
    required Set<String> unavailableNodeIds,
    required Set<String> blockedRequiredNodeIds,
    required Set<String> optionalDependencyWarnings,
  })  : unavailableOwnerIds = Set.unmodifiable(unavailableOwnerIds),
        unavailableNodeIds = Set.unmodifiable(unavailableNodeIds),
        blockedRequiredNodeIds = Set.unmodifiable(blockedRequiredNodeIds),
        optionalDependencyWarnings = Set.unmodifiable(optionalDependencyWarnings);

  bool get hasUnavailablePlugins => unavailableOwnerIds.isNotEmpty;

  /// False when any required dependency points at a node owned by a missing
  /// plugin. Missing optional dependencies remain warnings.
  bool get canRestoreWithoutMissingRequiredDependencies =>
      blockedRequiredNodeIds.isEmpty;

  bool get isFullyCompatible =>
      unavailableOwnerIds.isEmpty && optionalDependencyWarnings.isEmpty;
}

/// Checks a declarative plan against the plugins discovered by the host.
///
/// This checker does not load plugins, remove nodes, or choose a fallback
/// policy. The host decides whether to defer, reject, or degrade unavailable
/// plugin contributions.
class CompositionCompatibilityChecker {
  const CompositionCompatibilityChecker();

  CompositionCompatibilityReport check(
    CompositionPlan plan, {
    required Set<String> availablePluginIds,
    Set<String> coreOwnerIds = const {'core'},
  }) {
    final unavailableOwners = <String>{};
    final unavailableNodes = <String>{};
    final blockedRequired = <String>{};
    final optionalWarnings = <String>{};

    for (final node in plan.nodes.values) {
      if (coreOwnerIds.contains(node.ownerId) ||
          availablePluginIds.contains(node.ownerId)) {
        continue;
      }
      unavailableOwners.add(node.ownerId);
      unavailableNodes.add(node.id);
    }

    final unavailableIds = unavailableNodes;
    for (final node in plan.nodes.values) {
      for (final dependency in node.dependencies) {
        if (!unavailableIds.contains(dependency.nodeId)) continue;
        if (dependency.required) {
          blockedRequired.add(node.id);
        } else {
          optionalWarnings.add(node.id);
        }
      }
    }

    return CompositionCompatibilityReport(
      unavailableOwnerIds: unavailableOwners,
      unavailableNodeIds: unavailableNodes,
      blockedRequiredNodeIds: blockedRequired,
      optionalDependencyWarnings: optionalWarnings,
    );
  }
}

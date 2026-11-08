import 'dart:convert';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Exception thrown when a circular dependency chain is detected between plugins.
class PluginDependencyCycleException implements Exception {
  final List<String> cyclePath;
  const PluginDependencyCycleException(this.cyclePath);

  @override
  String toString() =>
      'PluginDependencyCycleException: Circular dependency detected: ${cyclePath.join(' -> ')}';
}

/// Node in the plugin dependency graph.
final class PluginDependencyNode {
  final PluginPackageManifest manifest;
  final Set<String> dependencyIds;

  PluginDependencyNode({required this.manifest, required this.dependencyIds});
}

/// Dependency graph representation for plugin packages.
class PluginDependencyGraph {
  final Map<String, PluginDependencyNode> _nodes = {};

  void add(PluginPackageManifest manifest) {
    final depIds = manifest.dependencies.map((d) => d.id.value).toSet();
    _nodes[manifest.id.value] = PluginDependencyNode(
      manifest: manifest,
      dependencyIds: depIds,
    );
  }

  PluginDependencyNode? getNode(String pluginId) => _nodes[pluginId];
  Iterable<PluginDependencyNode> get allNodes => _nodes.values;

  void clear() => _nodes.clear();
}

/// Resolves plugin packages into a deterministic activation plan with topological ordering.
class TopologicalPluginResolver {
  final PluginDependencyGraph graph;

  TopologicalPluginResolver({required this.graph});

  PluginResolutionPlan resolve() {
    _detectCycles();

    final resolved = <PluginPackageManifest>[];
    final visited = <String>{};
    final visiting = <String>{};

    final allSortedIds = graph.allNodes.map((n) => n.manifest.id.value).toList()
      ..sort();

    void visit(String id) {
      if (visited.contains(id)) return;
      visiting.add(id);

      final node = graph.getNode(id);
      if (node != null) {
        final sortedDeps = node.dependencyIds.toList()..sort();
        for (final depId in sortedDeps) {
          if (graph.getNode(depId) != null) {
            visit(depId);
          }
        }
        resolved.add(node.manifest);
      }

      visiting.remove(id);
      visited.add(id);
    }

    for (final id in allSortedIds) {
      if (!visited.contains(id)) {
        visit(id);
      }
    }

    return PluginResolutionPlan(plugins: resolved);
  }

  void _detectCycles() {
    final visited = <String>{};
    final stack = <String>[];
    final inStack = <String>{};

    void dfs(String current) {
      visited.add(current);
      stack.add(current);
      inStack.add(current);

      final node = graph.getNode(current);
      if (node != null) {
        for (final dep in node.dependencyIds) {
          if (!visited.contains(dep)) {
            if (graph.getNode(dep) != null) {
              dfs(dep);
            }
          } else if (inStack.contains(dep)) {
            final cycleIndex = stack.indexOf(dep);
            final cycleChain = [...stack.sublist(cycleIndex), dep];
            throw PluginDependencyCycleException(cycleChain);
          }
        }
      }

      stack.removeLast();
      inStack.remove(current);
    }

    final allIds = graph.allNodes.map((n) => n.manifest.id.value).toList()
      ..sort();
    for (final id in allIds) {
      if (!visited.contains(id)) {
        dfs(id);
      }
    }
  }
}

/// Ordered result of plugin dependency resolution.
final class PluginResolutionPlan {
  final List<PluginPackageManifest> plugins;
  final List<String> warnings;

  const PluginResolutionPlan({required this.plugins, this.warnings = const []});
}

/// Checks host API, platform, and edition compatibility.
class DefaultCompatibilityResolver {
  final SemanticVersion hostVersion;
  final String currentPlatform;
  final String currentEdition;

  DefaultCompatibilityResolver({
    required this.hostVersion,
    this.currentPlatform = 'macos',
    this.currentEdition = 'community',
  });

  CompatibilityResult evaluate(PluginPackageManifest manifest) {
    final issues = <CompatibilityIssue>[];

    if (!manifest.hostApi.isCompatible(hostVersion)) {
      issues.add(
        CompatibilityIssue(
          code: 'incompatible_host_api',
          message:
              'Plugin "${manifest.id.value}" requires host API ${manifest.hostApi.min} to ${manifest.hostApi.max ?? "latest"}, but runtime is $hostVersion',
        ),
      );
    }

    if (manifest.platform != null &&
        !manifest.platform!.supports(currentPlatform)) {
      issues.add(
        CompatibilityIssue(
          code: 'unsupported_platform',
          message:
              'Plugin "${manifest.id.value}" does not support platform "$currentPlatform"',
        ),
      );
    }

    return CompatibilityResult(compatible: issues.isEmpty, issues: issues);
  }
}

/// Service to serialize and deserialize alhambra.lock lockfiles.
class LockfileService {
  String serialize(PluginLockfile lockfile) {
    final map = {
      'schemaVersion': lockfile.schemaVersion,
      'plugins': {
        for (final entry in lockfile.plugins.entries)
          entry.key: {
            'version': entry.value.version.toString(),
            'source': entry.value.source.name,
            if (entry.value.integrityHash != null)
              'integrity': entry.value.integrityHash,
          },
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  PluginLockfile deserialize(String jsonContent) {
    final map = jsonDecode(jsonContent) as Map<String, dynamic>;
    final schemaVersion = map['schemaVersion'] as int? ?? 1;
    final pluginsMap = map['plugins'] as Map<String, dynamic>? ?? {};

    final plugins = <String, LockedPlugin>{};
    for (final entry in pluginsMap.entries) {
      final pMap = entry.value as Map<String, dynamic>;
      final version = SemanticVersion.parse(pMap['version'] as String);
      final source = PluginSource.values.firstWhere(
        (s) => s.name == (pMap['source'] as String? ?? 'user'),
        orElse: () => PluginSource.user,
      );
      plugins[entry.key] = LockedPlugin(
        id: PluginId(entry.key),
        version: version,
        source: source,
        integrityHash: pMap['integrity'] as String?,
      );
    }

    return PluginLockfile(schemaVersion: schemaVersion, plugins: plugins);
  }
}

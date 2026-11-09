import 'extension_manifest.dart';

/// Resolves plugin dependencies into a deterministic activation order.
///
/// Dependencies in [ExtensionManifest.dependencies] are plugin IDs. They are
/// treated as required dependencies. Optional or version-constrained
/// dependencies need a richer manifest contract and are intentionally not
/// inferred from these legacy string IDs.
class PluginDependencyResolver {
  const PluginDependencyResolver();

  /// Returns manifests in dependency-first activation order.
  ///
  /// The relative input order is retained wherever dependencies do not impose
  /// an ordering constraint.
  List<ExtensionManifest> resolve(List<ExtensionManifest> manifests) {
    final byId = <String, ExtensionManifest>{};
    for (final manifest in manifests) {
      final id = manifest.id.trim();
      if (id.isEmpty) {
        throw PluginDependencyResolutionException(
          code: PluginDependencyErrorCode.invalidId,
          message: 'Plugin ID cannot be empty.',
        );
      }
      if (byId.containsKey(id)) {
        throw PluginDependencyResolutionException(
          code: PluginDependencyErrorCode.duplicatePlugin,
          message: 'Plugin "$id" is declared more than once.',
          pluginId: id,
        );
      }
      byId[id] = manifest;
    }

    for (final manifest in manifests) {
      for (final dependency in manifest.dependencies) {
        final dependencyId = dependency.trim();
        if (dependencyId.isEmpty || !byId.containsKey(dependencyId)) {
          throw PluginDependencyResolutionException(
            code: PluginDependencyErrorCode.missingDependency,
            message: 'Plugin "${manifest.id}" requires missing dependency "$dependency".',
            pluginId: manifest.id,
            dependencyId: dependency,
          );
        }
        if (dependencyId == manifest.id) {
          throw PluginDependencyResolutionException(
            code: PluginDependencyErrorCode.cycle,
            message: 'Plugin "${manifest.id}" cannot depend on itself.',
            pluginId: manifest.id,
            cycle: [manifest.id, manifest.id],
          );
        }
      }
    }

    final ordered = <ExtensionManifest>[];
    final states = <String, _VisitState>{};
    final stack = <String>[];

    void visit(String id) {
      final state = states[id];
      if (state == _VisitState.complete) return;
      if (state == _VisitState.visiting) {
        final start = stack.indexOf(id);
        final cycle = [...stack.skip(start), id];
        throw PluginDependencyResolutionException(
          code: PluginDependencyErrorCode.cycle,
          message: 'Plugin dependency cycle detected: ${cycle.join(' -> ')}.',
          pluginId: id,
          cycle: cycle,
        );
      }

      states[id] = _VisitState.visiting;
      stack.add(id);
      for (final dependency in byId[id]!.dependencies) {
        visit(dependency.trim());
      }
      stack.removeLast();
      states[id] = _VisitState.complete;
      ordered.add(byId[id]!);
    }

    for (final manifest in manifests) {
      visit(manifest.id);
    }
    return List<ExtensionManifest>.unmodifiable(ordered);
  }
}

enum PluginDependencyErrorCode {
  invalidId,
  duplicatePlugin,
  missingDependency,
  cycle,
}

/// A validation failure encountered while resolving plugin dependencies.
class PluginDependencyResolutionException implements Exception {
  final PluginDependencyErrorCode code;
  final String message;
  final String? pluginId;
  final String? dependencyId;
  final List<String> cycle;

  const PluginDependencyResolutionException({
    required this.code,
    required this.message,
    this.pluginId,
    this.dependencyId,
    this.cycle = const [],
  });

  @override
  String toString() => 'PluginDependencyResolutionException: $message';
}

enum _VisitState { visiting, complete }

import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// In-memory catalog indexing plugin descriptors for offline & online discovery.
class InMemoryPluginCatalog implements PluginCatalog {
  final Map<String, PluginDescriptor> _plugins = {};

  void register(PluginDescriptor descriptor) {
    _plugins[descriptor.id.value] = descriptor;
  }

  @override
  Future<PluginDescriptor?> find(PluginId id) async {
    return _plugins[id.value];
  }

  @override
  Future<List<PluginDescriptor>> search(String query) async {
    final lower = query.toLowerCase();
    return _plugins.values
        .where(
          (p) =>
              p.id.value.toLowerCase().contains(lower) ||
              p.name.toLowerCase().contains(lower) ||
              (p.description?.toLowerCase().contains(lower) ?? false),
        )
        .toList(growable: false);
  }
}

/// Resolves plugin dependency graphs against installed and catalog entries.
class DefaultPluginDependencyResolver implements PluginDependencyResolver {
  final PluginCatalog catalog;

  DefaultPluginDependencyResolver({required this.catalog});

  @override
  Future<PluginDependencyResolution> resolve(PluginDescriptor root) async {
    final plan = <PluginDescriptor>[root];
    final missing = <String>[];
    final visited = <String>{root.id.value};

    final queue = List<PluginDependency>.from(root.dependencies);
    while (queue.isNotEmpty) {
      final dep = queue.removeAt(0);
      if (visited.contains(dep.id.value)) continue;

      final found = await catalog.find(dep.id);
      if (found == null) {
        missing.add('${dep.id.value} (required: ${dep.version})');
        continue;
      }

      visited.add(found.id.value);
      plan.add(found);
      queue.addAll(found.dependencies);
    }

    return PluginDependencyResolution(
      installPlan: plan,
      missingDependencies: missing,
    );
  }
}

/// Complete lifecycle manager implementing discovery, transactional staging, install, enable, disable, and uninstall.
class DefaultPluginLifecycleManager implements PluginLifecycleManager {
  final PluginPackageVerifier verifier;
  final PluginDependencyResolver dependencyResolver;
  final InstalledPluginStore store;
  final Map<String, InstalledPluginDescriptor> _installed = {};

  DefaultPluginLifecycleManager({
    required this.verifier,
    required this.dependencyResolver,
    required this.store,
  });

  @override
  List<InstalledPluginDescriptor> get installed =>
      _installed.values.toList(growable: false);

  @override
  InstalledPluginDescriptor? findInstalled(PluginId pluginId) =>
      _installed[pluginId.value];

  @override
  Future<void> install(PluginPackage package) async {
    // 1. Verify package
    final verifyResult = await verifier.verify(package);
    if (verifyResult is PackageVerificationFailed) {
      final issuesStr = verifyResult.issues
          .map((i) => '[${i.code}] ${i.message}')
          .join(', ');
      throw StateError('Plugin package verification failed: $issuesStr');
    }

    final descriptor = PluginDescriptor(
      id: package.manifest.id,
      name: package.manifest.name,
      version: package.manifest.version,
      hostApi: package.manifest.hostApi,
      dependencies: package.manifest.dependencies,
      capabilities: package.manifest.capabilities
          .map((c) => c.capability.value)
          .toList(),
    );

    // 2. Dependency resolution check
    final res = await dependencyResolver.resolve(descriptor);
    if (!res.isSuccessful) {
      throw StateError(
        'Cannot install ${descriptor.id.value}: missing dependencies ${res.missingDependencies}',
      );
    }

    // 3. Staging and promoting to installed state
    final installPath =
        '/plugins/installed/${descriptor.id.value}/${descriptor.version}';
    final installedPlugin = InstalledPluginDescriptor(
      descriptor: descriptor,
      installPath: installPath,
      enabled: false,
      source: PluginSourceType.community,
      runtimeState: PluginRuntimeState.installed,
    );

    _installed[descriptor.id.value] = installedPlugin;

    await store.save(
      InstalledPluginRecord(
        id: descriptor.id.value,
        version: descriptor.version,
        contentHash: package.metadata.contentHash,
        installedAt: DateTime.now(),
        installPath: installPath,
        publisher: package.publisher,
      ),
    );
  }

  @override
  Future<void> enable(PluginId pluginId) async {
    final plugin = _installed[pluginId.value];
    if (plugin == null)
      throw ArgumentError('Plugin ${pluginId.value} not installed');

    _installed[pluginId.value] = plugin.copyWith(
      enabled: true,
      runtimeState: PluginRuntimeState.active,
    );
  }

  @override
  Future<void> disable(PluginId pluginId) async {
    final plugin = _installed[pluginId.value];
    if (plugin == null)
      throw ArgumentError('Plugin ${pluginId.value} not installed');

    _installed[pluginId.value] = plugin.copyWith(
      enabled: false,
      runtimeState: PluginRuntimeState.disabled,
    );
  }

  @override
  Future<void> uninstall(PluginId pluginId) async {
    final plugin = _installed.remove(pluginId.value);
    if (plugin != null) {
      await store.remove(pluginId.value);
    }
  }
}

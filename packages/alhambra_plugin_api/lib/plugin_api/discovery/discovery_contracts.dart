import '../manifest/manifest_models.dart';
import '../plugins/plugin_sdk_contracts.dart';
import '../packaging/packaging_contracts.dart';

/// Pre-activation runtime-neutral plugin descriptor.
final class PluginDescriptor {
  final PluginId id;
  final String name;
  final SemanticVersion version;
  final HostApiConstraint hostApi;
  final String? description;
  final String? author;
  final List<PluginDependency> dependencies;
  final List<String> capabilities;

  const PluginDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.hostApi,
    this.description,
    this.author,
    this.dependencies = const [],
    this.capabilities = const [],
  });
}

/// Source origin of a plugin.
enum PluginSourceType {
  local,
  community,
  enterprise,
}

/// Explicit lifecycle runtime state machine.
enum PluginRuntimeState {
  discovered,
  installed,
  disabled,
  activating,
  active,
  deactivating,
  failed,
}

/// Record of an installed plugin with desired and active state.
final class InstalledPluginDescriptor {
  final PluginDescriptor descriptor;
  final String installPath;
  final bool enabled;
  final PluginSourceType source;
  final PluginRuntimeState runtimeState;

  const InstalledPluginDescriptor({
    required this.descriptor,
    required this.installPath,
    required this.enabled,
    required this.source,
    this.runtimeState = PluginRuntimeState.installed,
  });

  InstalledPluginDescriptor copyWith({
    PluginDescriptor? descriptor,
    String? installPath,
    bool? enabled,
    PluginSourceType? source,
    PluginRuntimeState? runtimeState,
  }) {
    return InstalledPluginDescriptor(
      descriptor: descriptor ?? this.descriptor,
      installPath: installPath ?? this.installPath,
      enabled: enabled ?? this.enabled,
      source: source ?? this.source,
      runtimeState: runtimeState ?? this.runtimeState,
    );
  }
}

/// Catalog abstraction for offline and online discovery.
abstract interface class PluginCatalog {
  Future<List<PluginDescriptor>> search(String query);
  Future<PluginDescriptor?> find(PluginId id);
}

/// Complete plan resolved by dependency solver.
final class PluginDependencyResolution {
  final List<PluginDescriptor> installPlan;
  final List<String> missingDependencies;
  final List<String> conflicts;

  const PluginDependencyResolution({
    required this.installPlan,
    this.missingDependencies = const [],
    this.conflicts = const [],
  });

  bool get isSuccessful => missingDependencies.isEmpty && conflicts.isEmpty;
}

/// Dependency resolver interface across catalogs and installed index.
abstract interface class PluginDependencyResolver {
  Future<PluginDependencyResolution> resolve(PluginDescriptor root);
}

/// Lifecycle management interface for discovery, install, enable, disable, uninstall.
abstract interface class PluginLifecycleManager {
  List<InstalledPluginDescriptor> get installed;
  Future<void> install(PluginPackage package);
  Future<void> uninstall(PluginId pluginId);
  Future<void> enable(PluginId pluginId);
  Future<void> disable(PluginId pluginId);
  InstalledPluginDescriptor? findInstalled(PluginId pluginId);
}

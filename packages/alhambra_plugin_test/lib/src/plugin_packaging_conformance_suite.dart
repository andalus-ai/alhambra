import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

import 'plugin_conformance_result.dart';

/// Side-effect-free conformance checks for package manifests, lockfiles and
/// the repository's current compiled-plugin discovery dependency contract.
///
/// This validates declarations; it does not download, unpack, execute, sign,
/// or sandbox plugin code.
final class PluginPackagingConformanceSuite {
  const PluginPackagingConformanceSuite();

  PluginConformanceResult validatePackageManifest(
    PluginPackageManifest manifest,
  ) {
    final issues = <PluginConformanceIssue>[];
    _requiredText(issues, 'manifest.id', manifest.id.value);
    _requiredText(issues, 'manifest.name', manifest.name);
    _validateVersion(issues, 'manifest.version', manifest.version);
    _validateVersion(issues, 'manifest.hostApi.min', manifest.hostApi.min);
    final max = manifest.hostApi.max;
    if (max != null) {
      _validateVersion(issues, 'manifest.hostApi.max', max);
      if (max <= manifest.hostApi.min) {
        _issue(issues, 'manifest.host_api.range', 'manifest.hostApi.max',
            'Maximum host API version must be greater than the inclusive minimum.');
      }
    }

    final dependencyIds = <String, String>{};
    void addDependencies(List<PluginDependency> dependencies, String kind) {
      for (var index = 0; index < dependencies.length; index++) {
        final dependency = dependencies[index];
        final id = dependency.id.value;
        final path = 'manifest.$kind[$index].id';
        _requiredText(issues, path, id);
        if (id == manifest.id.value && id.isNotEmpty) {
          _issue(issues, 'manifest.dependency.self', path,
              'A plugin cannot depend on itself.');
        }
        final previous = dependencyIds[id];
        if (previous != null) {
          _issue(issues, 'manifest.dependency.duplicate', path,
              'Dependency "$id" is already declared at $previous.');
        } else if (id.isNotEmpty) {
          dependencyIds[id] = path;
        }
      }
    }

    addDependencies(manifest.dependencies, 'dependencies');
    addDependencies(manifest.optionalDependencies, 'optionalDependencies');

    final capabilityIds = <String>{};
    for (var index = 0; index < manifest.capabilities.length; index++) {
      final id = manifest.capabilities[index].capability.value;
      final path = 'manifest.capabilities[$index].capability';
      _requiredText(issues, path, id);
      if (id.isNotEmpty && !capabilityIds.add(id)) {
        _issue(issues, 'manifest.capability.duplicate', path,
            'Capability "$id" is declared more than once.');
      }
    }

    final edition = manifest.edition?.minimumEdition;
    if (edition != null) {
      _requiredText(issues, 'manifest.edition.minimumEdition', edition);
    }
    final platforms = manifest.platform?.supportedPlatforms;
    if (platforms != null) {
      if (platforms.isEmpty) {
        _issue(issues, 'manifest.platform.empty', 'manifest.platform.supportedPlatforms',
            'An explicit platform constraint must contain at least one platform.');
      }
      final seenPlatforms = <String>{};
      for (var index = 0; index < platforms.length; index++) {
        final platform = platforms[index];
        final path = 'manifest.platform.supportedPlatforms[$index]';
        _requiredText(issues, path, platform);
        if (platform.isNotEmpty && !seenPlatforms.add(platform.toLowerCase())) {
          _issue(issues, 'manifest.platform.duplicate', path,
              'Platform "$platform" is declared more than once.');
        }
      }
    }
    return PluginConformanceResult(issues);
  }

  PluginConformanceResult validateLockfile(PluginLockfile lockfile) {
    final issues = <PluginConformanceIssue>[];
    if (lockfile.schemaVersion < 1) {
      _issue(issues, 'lockfile.schema_version', 'lockfile.schemaVersion',
          'Lockfile schema version must be at least 1.');
    }
    for (final entry in lockfile.plugins.entries) {
      final path = 'lockfile.plugins["${entry.key}"]';
      final plugin = entry.value;
      _requiredText(issues, '$path.id', plugin.id.value);
      if (entry.key != plugin.id.value) {
        _issue(issues, 'lockfile.key_mismatch', path,
            'Map key "${entry.key}" must match locked plugin ID "${plugin.id.value}".');
      }
      _validateVersion(issues, '$path.version', plugin.version);
      final hash = plugin.integrityHash;
      if (hash != null) {
        _requiredText(issues, '$path.integrityHash', hash);
      }
    }
    return PluginConformanceResult(issues);
  }

  /// Checks package header metadata against its declared manifest.
  PluginConformanceResult validatePackageMetadata(
    PluginPackageManifest manifest,
    PluginPackageMetadata metadata,
  ) {
    final issues = <PluginConformanceIssue>[];
    _requiredText(issues, 'packageMetadata.packageId', metadata.packageId);
    _requiredText(issues, 'packageMetadata.contentHash', metadata.contentHash);
    if (metadata.packageId != manifest.id.value) {
      _issue(issues, 'package.id_mismatch', 'packageMetadata.packageId',
          'Package ID must match manifest ID "${manifest.id.value}".');
    }
    if (metadata.version != manifest.version) {
      _issue(issues, 'package.version_mismatch', 'packageMetadata.version',
          'Package version must match the manifest version.');
    }
    if (metadata.formatVersion < 1) {
      _issue(issues, 'package.format_version', 'packageMetadata.formatVersion',
          'Package format version must be positive.');
    }
    return PluginConformanceResult(issues);
  }

  /// Validates the actual legacy discovery graph and its dependency-first plan.
  ///
  /// [ExtensionManifest.dependencies] currently contains required plugin IDs
  /// only. Versioned and optional dependency resolution belongs to the richer
  /// PluginPackageManifest contract and is not inferred here.
  PluginConformanceResult validateDiscoveryGraph(
    Iterable<ExtensionManifest> manifests,
  ) {
    try {
      const PluginDependencyResolver().resolve(manifests.toList(growable: false));
      return PluginConformanceResult(const []);
    } on PluginDependencyResolutionException catch (error) {
      return PluginConformanceResult([
        PluginConformanceIssue(
          code: 'discovery.${error.code.name}',
          message: error.message,
          path: error.pluginId == null ? null : 'plugins["${error.pluginId}"]',
        ),
      ]);
    }
  }

  void _validateVersion(
    List<PluginConformanceIssue> issues,
    String path,
    SemanticVersion version,
  ) {
    if (version.major < 0 || version.minor < 0 || version.patch < 0) {
      _issue(issues, 'version.negative_component', path,
          'Semantic version components must not be negative.');
    }
    for (var index = 0; index < version.prerelease.length; index++) {
      _requiredText(issues, '$path.prerelease[$index]', version.prerelease[index]);
    }
  }

  void _requiredText(
    List<PluginConformanceIssue> issues,
    String path,
    String value,
  ) {
    if (value.trim().isEmpty) {
      _issue(issues, 'value.empty', path, 'Value must not be empty or whitespace.');
    } else if (value != value.trim()) {
      _issue(issues, 'value.untrimmed', path,
          'Value must not contain surrounding whitespace.');
    }
  }

  void _issue(
    List<PluginConformanceIssue> issues,
    String code,
    String path,
    String message,
  ) {
    issues.add(PluginConformanceIssue(code: code, path: path, message: message));
  }
}

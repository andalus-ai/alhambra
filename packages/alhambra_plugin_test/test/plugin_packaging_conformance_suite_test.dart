import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:flutter_test/flutter_test.dart';

PluginPackageManifest packageManifest({
  String id = 'example.editor',
  List<PluginDependency> dependencies = const [],
  List<PluginDependency> optionalDependencies = const [],
  List<CapabilityRequest> capabilities = const [],
  PlatformConstraint? platform,
}) => PluginPackageManifest(
  id: PluginId(id),
  name: 'Example editor',
  version: const SemanticVersion(1, 2, 3),
  hostApi: HostApiConstraint(min: const SemanticVersion(1, 0, 0)),
  dependencies: dependencies,
  optionalDependencies: optionalDependencies,
  capabilities: capabilities,
  platform: platform,
);

void main() {
  const suite = PluginPackagingConformanceSuite();

  group('package manifest conformance', () {
    test('accepts a valid manifest', () {
      expect(suite.validatePackageManifest(packageManifest()).isConformant, isTrue);
    });

    test('rejects self and duplicate dependencies across required and optional lists', () {
      final result = suite.validatePackageManifest(packageManifest(
        dependencies: const [PluginDependency(
          id: PluginId('example.editor'), version: WildcardVersionConstraint())],
        optionalDependencies: const [PluginDependency(
          id: PluginId('example.shared'), version: WildcardVersionConstraint())],
      ));
      expect(result.issues.map((issue) => issue.code), contains('manifest.dependency.self'));
      final duplicate = suite.validatePackageManifest(packageManifest(
        dependencies: const [PluginDependency(
          id: PluginId('example.shared'), version: WildcardVersionConstraint())],
        optionalDependencies: const [PluginDependency(
          id: PluginId('example.shared'), version: WildcardVersionConstraint())],
      ));
      expect(duplicate.issues.map((issue) => issue.code),
          contains('manifest.dependency.duplicate'));
    });

    test('rejects duplicate capabilities and invalid platform declarations', () {
      final result = suite.validatePackageManifest(packageManifest(
        capabilities: const [
          CapabilityRequest(capability: CapabilityId('example.read')),
          CapabilityRequest(capability: CapabilityId('example.read')),
        ],
        platform: const PlatformConstraint(supportedPlatforms: ['linux', 'LINUX']),
      ));
      expect(result.issues.map((issue) => issue.code),
          containsAll(['manifest.capability.duplicate', 'manifest.platform.duplicate']));
    });

    test('rejects invalid host API ranges and negative version components', () {
      final result = suite.validatePackageManifest(PluginPackageManifest(
        id: const PluginId('example.editor'),
        name: 'Editor',
        version: const SemanticVersion(-1, 0, 0),
        hostApi: HostApiConstraint(
          min: const SemanticVersion(2, 0, 0),
          max: const SemanticVersion(2, 0, 0),
        ),
      ));
      expect(result.issues.map((issue) => issue.code),
          containsAll(['version.negative_component', 'manifest.host_api.range']));
    });
  });

  group('lockfile and package metadata conformance', () {
    test('requires lockfile keys to match locked plugin IDs', () {
      final result = suite.validateLockfile(const PluginLockfile(
        schemaVersion: 1,
        plugins: {
          'wrong.key': LockedPlugin(
            id: PluginId('actual.plugin'),
            version: SemanticVersion(1, 0, 0),
            source: PluginSource.user,
          ),
        },
      ));
      expect(result.issues.map((issue) => issue.code), contains('lockfile.key_mismatch'));
    });

    test('checks package ID, version, content hash and format version', () {
      final manifest = packageManifest();
      final result = suite.validatePackageMetadata(
        manifest,
        const PluginPackageMetadata(
          packageId: 'wrong.id',
          version: SemanticVersion(2, 0, 0),
          contentHash: ' ',
          formatVersion: 0,
        ),
      );
      expect(result.issues.map((issue) => issue.code),
          containsAll(['value.empty', 'package.id_mismatch',
            'package.version_mismatch', 'package.format_version']));
    });
  });

  group('discovery graph conformance', () {
    ExtensionManifest manifest(String id, {List<String> dependencies = const []}) =>
        ExtensionManifest(id: id, name: id, version: '1.0.0', dependencies: dependencies);

    test('accepts a complete dependency-first graph', () {
      final result = suite.validateDiscoveryGraph([
        manifest('editor', dependencies: ['core']),
        manifest('core'),
      ]);
      expect(result.isConformant, isTrue);
    });

    test('reports missing, duplicate and cyclic discovery declarations', () {
      final missing = suite.validateDiscoveryGraph([
        manifest('editor', dependencies: ['missing']),
      ]);
      expect(missing.issues.single.code, 'discovery.missingDependency');

      final duplicate = suite.validateDiscoveryGraph([manifest('same'), manifest('same')]);
      expect(duplicate.issues.single.code, 'discovery.duplicatePlugin');

      final cycle = suite.validateDiscoveryGraph([
        manifest('a', dependencies: ['b']),
        manifest('b', dependencies: ['a']),
      ]);
      expect(cycle.issues.single.code, 'discovery.cycle');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

const _testHash = 'sha256:0000000000000000000000000000000000000000000000000000000000000000';

class _FakeIntegrityVerifier implements PluginPayloadIntegrityVerifier {
  @override
  Future<PluginPayloadDigest> digest(PluginPackage package) async =>
      const PluginPayloadDigest(algorithm: 'sha256', value: '0000000000000000000000000000000000000000000000000000000000000000');
}

class _FakeSignatureVerifier implements PluginCryptographicSignatureVerifier {
  final bool result;
  const _FakeSignatureVerifier({this.result = true});

  @override
  Future<bool> verify({
    required String algorithm,
    required String publicKey,
    required String signature,
    required List<int> message,
  }) async => result;
}

class _MockPluginPackage implements PluginPackage {
  @override
  final PluginPackageManifest manifest;
  @override
  final PluginPackageMetadata metadata;
  @override
  final PluginPublisher? publisher;
  @override
  final PluginPackageSignature? signature;

  _MockPluginPackage({
    required this.manifest,
    required this.metadata,
    this.publisher,
    this.signature,
  });

  @override
  Stream<List<int>> readPayload(String path) async* {
    yield [1, 2, 3];
  }
}

void main() {
  group('UI-19: UI State Projection & Reactive Rendering', () {
    late DefaultUiProjectionRegistry registry;

    setUp(() {
      registry = DefaultUiProjectionRegistry();
    });

    test('registers, finds and removes projections with owner cleanup', () {
      const projection = CommandUiProjection(badge: '3', tooltip: 'Sync Git');
      registry.register<CommandAvailabilityResult, ContributionUiState>(
        id: 'git.sync.projection',
        ownerId: 'plugin.git',
        projection: projection,
      );

      expect(registry.registeredIds, contains('git.sync.projection'));
      final found = registry
          .find<CommandAvailabilityResult, ContributionUiState>(
            'git.sync.projection',
          );
      expect(found, isNotNull);

      final state = found!.project(
        const CommandAvailabilityResult.always(),
        const UiProjectionContext(workspaceId: WorkspaceId('ws1')),
      );
      expect(state.visible, isTrue);
      expect(state.enabled, isTrue);
      expect(state.badge, equals('3'));

      registry.removeOwner('plugin.git');
      expect(registry.find('git.sync.projection'), isNull);
    });
  });

  group('UI-20: Plugin Packaging, Verification & Trust Store', () {
    late DefaultPluginTrustStore trustStore;
    late DefaultPluginPackageVerifier verifier;

    setUp(() {
      trustStore = DefaultPluginTrustStore();
      verifier = DefaultPluginPackageVerifier(
        trustStore: trustStore,
        integrityVerifier: _FakeIntegrityVerifier(),
        signatureVerifier: const _FakeSignatureVerifier(),
      );
    });

    test('verifies unsigned package under default community policy', () async {
      final pkg = _MockPluginPackage(
        manifest: PluginPackageManifest(
          id: const PluginId('org.example.tools'),
          name: 'Example Tools',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
        ),
        metadata: PluginPackageMetadata(
          packageId: 'org.example.tools',
          version: SemanticVersion.parse('1.0.0'),
          contentHash: _testHash,
          formatVersion: 1,
        ),
      );

      final res = await verifier.verify(pkg);
      expect(res, isA<PackageVerified>());
      expect((res as PackageVerified).trust, equals(PluginTrustLevel.unsigned));
    });

    test('rejects package with unsupported format version', () async {
      final pkg = _MockPluginPackage(
        manifest: PluginPackageManifest(
          id: const PluginId('org.example.future'),
          name: 'Future Tools',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
        ),
        metadata: PluginPackageMetadata(
          packageId: 'org.example.future',
          version: SemanticVersion.parse('1.0.0'),
          contentHash: _testHash,
          formatVersion: 99,
        ),
      );

      final res = await verifier.verify(pkg);
      expect(res, isA<PackageVerificationFailed>());
      final failed = res as PackageVerificationFailed;
      expect(failed.issues.any((i) => i.code == 'UNSUPPORTED_FORMAT'), isTrue);
    });

    test('verifies signed package when key is in trust store', () async {
      trustStore.addTrustedKey(
        const TrustedKey(
          keyId: 'key_123',
          algorithm: 'ed25519',
          publicKey: 'pub_abc',
        ),
      );

      final pkg = _MockPluginPackage(
        manifest: PluginPackageManifest(
          id: const PluginId('org.example.signed'),
          name: 'Signed Tools',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
        ),
        metadata: PluginPackageMetadata(
          packageId: 'org.example.signed',
          version: SemanticVersion.parse('1.0.0'),
          contentHash: _testHash,
          formatVersion: 1,
        ),
        signature: const PluginPackageSignature(
          algorithm: 'ed25519',
          keyId: 'key_123',
          signature: 'sig_data',
        ),
      );

      final res = await verifier.verify(pkg);
      expect(res, isA<PackageVerified>());
      expect((res as PackageVerified).trust, equals(PluginTrustLevel.verified));
    });
  });

  group('UI-21: Plugin Manifest, Discovery & Lifecycle Management', () {
    late InMemoryPluginCatalog catalog;
    late DefaultPluginDependencyResolver resolver;
    late InMemoryInstalledPluginStore store;
    late DefaultPluginLifecycleManager manager;

    setUp(() {
      catalog = InMemoryPluginCatalog();
      resolver = DefaultPluginDependencyResolver(catalog: catalog);
      store = InMemoryInstalledPluginStore();
      manager = DefaultPluginLifecycleManager(
        verifier: DefaultPluginPackageVerifier(
          integrityVerifier: _FakeIntegrityVerifier(),
        ),
        dependencyResolver: resolver,
        store: store,
      );
    });

    test('searches and discovers plugins in catalog', () async {
      catalog.register(
        PluginDescriptor(
          id: const PluginId('com.docker.tools'),
          name: 'Docker Integration',
          version: SemanticVersion.parse('2.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
          description: 'Docker container management',
        ),
      );

      final results = await catalog.search('container');
      expect(results.length, equals(1));
      expect(results.first.id.value, equals('com.docker.tools'));
    });

    test('installs, enables, disables and uninstalls plugin through state transitions', () async {
      final pkg = _MockPluginPackage(
        manifest: PluginPackageManifest(
          id: const PluginId('com.alhambra.git'),
          name: 'Git Integration',
          version: SemanticVersion.parse('1.5.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
        ),
        metadata: PluginPackageMetadata(
          packageId: 'com.alhambra.git',
          version: SemanticVersion.parse('1.5.0'),
          contentHash: _testHash,
          formatVersion: 1,
        ),
      );

      await manager.install(pkg);
      expect(manager.installed.length, equals(1));
      expect(manager.installed.first.enabled, isFalse);
      expect(
        manager.installed.first.runtimeState,
        equals(PluginRuntimeState.installed),
      );

      const gitId = PluginId('com.alhambra.git');
      await manager.enable(gitId);
      expect(manager.findInstalled(gitId)?.enabled, isTrue);
      expect(
        manager.findInstalled(gitId)?.runtimeState,
        equals(PluginRuntimeState.active),
      );

      await manager.disable(gitId);
      expect(manager.findInstalled(gitId)?.enabled, isFalse);
      expect(
        manager.findInstalled(gitId)?.runtimeState,
        equals(PluginRuntimeState.disabled),
      );

      await manager.uninstall(gitId);
      expect(manager.findInstalled(gitId), isNull);
    });
  });

  group('UI-22: Dependency Injection & Service Graph', () {
    late DefaultWorkspaceManager wsManager;

    setUp(() {
      wsManager = DefaultWorkspaceManager();
    });

    test(
      'manages multiple workspace lifecycles and service boundaries',
      () async {
        final ws1 = await wsManager.createWorkspace();
        final ws2 = await wsManager.createWorkspace();

        expect(wsManager.workspaceIds, containsAll([ws1, ws2]));

        final services1 = wsManager.get(ws1);
        services1.put('key1', 'value1');

        final services2 = wsManager.get(ws2);
        expect(services2.get('key1'), isNull);

        await wsManager.closeWorkspace(ws1);
        expect(wsManager.workspaceIds, isNot(contains(ws1)));
        expect(wsManager.workspaceIds, contains(ws2));
      },
    );

    test('ExtensionRuntime wires all UI 19-22 runtime managers', () {
      final runtime = ExtensionRuntime();
      expect(runtime.uiProjectionRegistry, isNotNull);
      expect(runtime.pluginTrustStore, isNotNull);
      expect(runtime.pluginPackageVerifier, isNotNull);
      expect(runtime.pluginCatalog, isNotNull);
      expect(runtime.pluginLifecycleManager, isNotNull);
      expect(runtime.workspaceManager, isNotNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  const id = CapabilityId('sample.storage');

  group('CapabilityProviderRegistry', () {
    test('registers owners and publishes deterministic snapshots', () async {
      final registry = CapabilityProviderRegistry();
      final events = <CapabilityProviderSnapshot>[];
      final subscription = registry.changes.listen(events.add);

      final first = registry.register(
        ownerId: 'z-provider',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 1),
        ],
      );
      final second = registry.register(
        ownerId: 'a-provider',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 2, minor: 1),
        ],
      );

      expect(first.revision, 1);
      expect(second.revision, 2);
      expect(second.declarations.map((d) => d.version), ['1.0.0', '2.1.0']);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.revision), [1, 2]);

      await subscription.cancel();
      await registry.close();
    });

    test('rejects duplicate owner registration and supports atomic replace', () {
      final registry = CapabilityProviderRegistry();
      registry.register(
        ownerId: 'storage',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 1),
        ],
      );

      expect(
        () => registry.register(ownerId: 'storage', declarations: const []),
        throwsStateError,
      );

      final updated = registry.replace(
        ownerId: 'storage',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 2, minor: 3),
        ],
      );
      expect(updated.revision, 2);
      expect(updated.declarations.single.version, '2.3.0');
    });

    test('withdrawal removes all owner declarations and is idempotent', () {
      final registry = CapabilityProviderRegistry();
      registry.register(
        ownerId: 'storage',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 1),
          PluginCapabilityDeclaration(id: id, major: 2),
        ],
      );

      expect(registry.unregister('storage'), isTrue);
      expect(registry.snapshot().declarations, isEmpty);
      expect(registry.revision, 2);
      expect(registry.unregister('storage'), isFalse);
      expect(registry.revision, 2);
    });

    test('snapshots are immutable and remain stable after mutations', () {
      final registry = CapabilityProviderRegistry();
      final before = registry.register(
        ownerId: 'storage',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 1),
        ],
      );

      registry.replace(
        ownerId: 'storage',
        declarations: const [
          PluginCapabilityDeclaration(id: id, major: 2),
        ],
      );

      expect(before.revision, 1);
      expect(before.declarations.single.version, '1.0.0');
      expect(
        () => before.declarations.add(
          const PluginCapabilityDeclaration(id: id, major: 3),
        ),
        throwsUnsupportedError,
      );
    });

    test('validates owner identifiers and rejects operations after close', () async {
      final registry = CapabilityProviderRegistry();
      expect(
        () => registry.register(ownerId: '  ', declarations: const []),
        throwsArgumentError,
      );
      await registry.close();
      expect(
        () => registry.snapshot(),
        returnsNormally,
      );
      expect(
        () => registry.unregister('storage'),
        throwsStateError,
      );
    });
  });

  test('fresh registry snapshot feeds the existing negotiator', () {
    final registry = CapabilityProviderRegistry();
    const negotiator = PluginCapabilityNegotiator();
    registry.register(
      ownerId: 'builtin-storage',
      declarations: const [
        PluginCapabilityDeclaration(id: id, major: 1, minor: 2),
      ],
    );

    final result = negotiator.negotiate(
      requirements: const [
        PluginCapabilityRequirement(id: id, major: 1, minimumMinor: 2),
      ],
      declarations: registry.snapshot().declarations,
    );

    expect(result.canActivate, isTrue);
    expect(result.selected[id]!.version, '1.2.0');
  });
}

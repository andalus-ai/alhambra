import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('CompositionSnapshotCodec', () {
    test('round trips every built-in node type and dependency metadata', () {
      final graph = CompositionGraph()
        ..add(ServiceNode(serviceId: 'auth', ownerId: 'core'))
        ..add(CommandNode(
          commandId: 'save',
          ownerId: 'editor',
          dependencies: {const CompositionDependency('service:auth')},
        ))
        ..add(ViewNode(viewId: 'home', ownerId: 'shell'))
        ..add(UiContributionNode(
          contributionId: 'toolbar',
          surfaceId: 'main',
          ownerId: 'editor',
          dependencies: {const CompositionDependency('service:auth', required: false)},
        ))
        ..add(ShellRegionNode(regionId: 'sidebar', ownerId: 'shell'));

      final codec = CompositionSnapshotCodec();
      final snapshot = codec.encode(CompositionPlan.fromGraph(graph), generation: 7);
      final json = encodeCompositionSnapshotJson(snapshot);
      final decoded = decodeCompositionSnapshotJson(json);
      final restored = codec.decode(decoded);

      expect(restored.nodes.keys.toSet(), graph.nodes.keys.toSet());
      expect(restored.nodes['command:save']!.dependencies.single.nodeId, 'service:auth');
      expect(restored.nodes['contribution:toolbar']!.dependencies.single.required, isFalse);
      expect((restored.nodes['contribution:toolbar'] as UiContributionNode).surfaceId, 'main');
    });

    test('rejects unsupported schema versions', () {
      final codec = CompositionSnapshotCodec();
      expect(
        () => codec.decode(const CompositionSnapshot(
          schemaVersion: 99,
          generation: 1,
          nodes: [],
        )),
        throwsFormatException,
      );
    });

    test('rejects missing required dependencies and cycles', () {
      final codec = CompositionSnapshotCodec();
      final missing = codec.encode(
        CompositionPlan.fromGraph(CompositionGraph()
          ..add(CommandNode(
            commandId: 'run',
            ownerId: 'plugin',
            dependencies: {const CompositionDependency('service:missing')},
          ))),
        generation: 1,
      );
      expect(() => codec.decode(missing), throwsFormatException);

      final cyclicGraph = CompositionGraph()
        ..add(CommandNode(
          commandId: 'a',
          ownerId: 'plugin',
          dependencies: {const CompositionDependency('command:b')},
        ))
        ..add(CommandNode(
          commandId: 'b',
          ownerId: 'plugin',
          dependencies: {const CompositionDependency('command:a')},
        ));
      final cyclicSnapshot = CompositionSnapshot(
        schemaVersion: 1,
        generation: 1,
        nodes: [
          {
            'type': 'command',
            'commandId': 'a',
            'id': 'command:a',
            'ownerId': 'plugin',
            'phase': 'commands',
            'dependencies': [{'nodeId': 'command:b', 'required': true}],
          },
          {
            'type': 'command',
            'commandId': 'b',
            'id': 'command:b',
            'ownerId': 'plugin',
            'phase': 'commands',
            'dependencies': [{'nodeId': 'command:a', 'required': true}],
          },
        ],
      );
      expect(() => codec.decode(cyclicSnapshot), throwsFormatException);
      expect(cyclicGraph.validate(), isNotEmpty);
    });
  });

  group('CompositionPersistence', () {
    test('increments generation and restores a validated plan', () async {
      final store = InMemoryCompositionSnapshotStore();
      final persistence = CompositionPersistence(store: store);
      final graph = CompositionGraph()
        ..add(ServiceNode(serviceId: 'settings', ownerId: 'core'))
        ..add(ViewNode(
          viewId: 'preferences',
          ownerId: 'settings-ui',
          dependencies: {const CompositionDependency('service:settings')},
        ));

      final first = await persistence.save(CompositionPlan.fromGraph(graph));
      final second = await persistence.save(CompositionPlan.fromGraph(graph));
      final restored = await persistence.restore();

      expect(first.generation, 1);
      expect(second.generation, 2);
      expect(restored!.nodes.keys.toSet(), graph.nodes.keys.toSet());
      expect(restored.activationOrder.first.id, 'service:settings');
    });

    test('returns null for an empty store and supports clearing', () async {
      final persistence = CompositionPersistence(
        store: InMemoryCompositionSnapshotStore(),
      );
      expect(await persistence.restore(), isNull);
      await persistence.save(CompositionPlan.fromGraph(
        CompositionGraph()..add(ServiceNode(serviceId: 'cache', ownerId: 'core')),
      ));
      await persistence.clear();
      expect(await persistence.restore(), isNull);
    });
  });
}

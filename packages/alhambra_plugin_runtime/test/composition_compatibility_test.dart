import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('CompositionSnapshotMigrator', () {
    test('applies consecutive migrations without mutating source', () {
      final source = const CompositionSnapshot(
        schemaVersion: 1,
        generation: 4,
        nodes: [
          {'id': 'service:cache', 'ownerId': 'core'},
        ],
      );
      final migrator = CompositionSnapshotMigrator([
        CompositionSnapshotMigration(
          fromVersion: 1,
          toVersion: 2,
          migrate: (nodes) => nodes
              .map((node) => {...node, 'enabled': true})
              .toList(growable: false),
        ),
        CompositionSnapshotMigration(
          fromVersion: 2,
          toVersion: 3,
          migrate: (nodes) => nodes
              .map((node) => {...node, 'metadata': <String, Object?>{}})
              .toList(growable: false),
        ),
      ]);

      final migrated = migrator.migrate(source, targetSchemaVersion: 3);

      expect(migrated.schemaVersion, 3);
      expect(migrated.generation, 4);
      expect(migrated.nodes.single['enabled'], isTrue);
      expect(migrated.nodes.single['metadata'], isA<Map>());
      expect(source.schemaVersion, 1);
      expect(source.nodes.single.containsKey('enabled'), isFalse);
    });

    test('fails closed when a migration step is missing', () {
      final migrator = CompositionSnapshotMigrator([]);
      expect(
        () => migrator.migrate(
          const CompositionSnapshot(schemaVersion: 1, generation: 1, nodes: []),
          targetSchemaVersion: 2,
        ),
        throwsFormatException,
      );
    });

    test('rejects downgrades and duplicate migration sources', () {
      expect(
        () => CompositionSnapshotMigrator([
          CompositionSnapshotMigration(fromVersion: 1, toVersion: 2, migrate: (n) => n),
          CompositionSnapshotMigration(fromVersion: 1, toVersion: 2, migrate: (n) => n),
        ]),
        throwsArgumentError,
      );
      expect(
        () => CompositionSnapshotMigrator([]).migrate(
          const CompositionSnapshot(schemaVersion: 2, generation: 1, nodes: []),
          targetSchemaVersion: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CompositionCompatibilityChecker', () {
    test('reports missing plugin owners and required versus optional dependents', () {
      final graph = CompositionGraph()
        ..add(ServiceNode(serviceId: 'auth', ownerId: 'security-plugin'))
        ..add(CommandNode(
          commandId: 'save',
          ownerId: 'editor-plugin',
          dependencies: {const CompositionDependency('service:auth')},
        ))
        ..add(ViewNode(
          viewId: 'help',
          ownerId: 'help-plugin',
          dependencies: {
            const CompositionDependency('service:auth', required: false),
          },
        ))
        ..add(ServiceNode(serviceId: 'core-cache', ownerId: 'core'));

      final report = const CompositionCompatibilityChecker().check(
        CompositionPlan.fromGraph(graph),
        availablePluginIds: {'editor-plugin', 'help-plugin'},
      );

      expect(report.unavailableOwnerIds, {'security-plugin'});
      expect(report.unavailableNodeIds, {'service:auth'});
      expect(report.blockedRequiredNodeIds, {'command:save'});
      expect(report.optionalDependencyWarnings, {'view:help'});
      expect(report.canRestoreWithoutMissingRequiredDependencies, isFalse);
      expect(report.isFullyCompatible, isFalse);
    });

    test('accepts a plan whose owners are installed or core-owned', () {
      final graph = CompositionGraph()
        ..add(ServiceNode(serviceId: 'auth', ownerId: 'security-plugin'))
        ..add(CommandNode(
          commandId: 'save',
          ownerId: 'core',
          dependencies: {const CompositionDependency('service:auth')},
        ));

      final report = const CompositionCompatibilityChecker().check(
        CompositionPlan.fromGraph(graph),
        availablePluginIds: {'security-plugin'},
      );

      expect(report.isFullyCompatible, isTrue);
      expect(report.unavailableNodeIds, isEmpty);
    });
  });
}

import 'composition_persistence.dart';

/// A single, deterministic composition snapshot schema migration.
typedef CompositionSnapshotMigrationCallback =
    List<Map<String, Object?>> Function(List<Map<String, Object?>> nodes);

class CompositionSnapshotMigration {
  final int fromVersion;
  final int toVersion;
  final CompositionSnapshotMigrationCallback migrate;

  const CompositionSnapshotMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  }) : assert(fromVersion >= 1),
       assert(toVersion == fromVersion + 1);
}

/// Applies explicitly registered, one-version-at-a-time snapshot migrations.
///
/// Migrations operate on declarative node maps only. They must not load plugins,
/// instantiate runtime objects, or perform external side effects.
class CompositionSnapshotMigrator {
  final Map<int, CompositionSnapshotMigration> _migrations;

  CompositionSnapshotMigrator(Iterable<CompositionSnapshotMigration> migrations)
      : _migrations = _index(migrations);

  static Map<int, CompositionSnapshotMigration> _index(
    Iterable<CompositionSnapshotMigration> migrations,
  ) {
    final result = <int, CompositionSnapshotMigration>{};
    for (final migration in migrations) {
      if (result.containsKey(migration.fromVersion)) {
        throw ArgumentError(
          'Duplicate composition migration from schema ${migration.fromVersion}.',
        );
      }
      result[migration.fromVersion] = migration;
    }
    return Map.unmodifiable(result);
  }

  /// Returns a migrated copy, leaving [source] and its node maps untouched.
  CompositionSnapshot migrate(
    CompositionSnapshot source, {
    required int targetSchemaVersion,
  }) {
    if (source.schemaVersion < 1 || source.generation < 1) {
      throw const FormatException('Snapshot header is invalid.');
    }
    if (targetSchemaVersion < source.schemaVersion) {
      throw ArgumentError.value(
        targetSchemaVersion,
        'targetSchemaVersion',
        'Downgrade migrations are not supported.',
      );
    }

    var version = source.schemaVersion;
    var nodes = source.nodes.map(_copyNode).toList(growable: false);
    while (version < targetSchemaVersion) {
      final migration = _migrations[version];
      if (migration == null) {
        throw FormatException(
          'No composition snapshot migration registered from schema $version.',
        );
      }
      try {
        nodes = migration.migrate(nodes).map(_copyNode).toList(growable: false);
      } on Object catch (error) {
        throw FormatException(
          'Composition snapshot migration $version -> ${version + 1} failed: $error',
        );
      }
      version = migration.toVersion;
    }

    return CompositionSnapshot(
      schemaVersion: version,
      generation: source.generation,
      nodes: nodes,
    );
  }

  static Map<String, Object?> _copyNode(Map<String, Object?> node) =>
      Map<String, Object?>.from(node);
}

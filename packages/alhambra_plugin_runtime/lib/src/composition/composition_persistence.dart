import 'dart:convert';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'composition_graph.dart';
import 'composition_plan.dart';

/// A versioned, declarative snapshot of a composition graph.
///
/// Runtime objects, callbacks, service instances, and plugin code are
/// deliberately excluded. The snapshot contains only stable contribution
/// identity and dependency metadata.
class CompositionSnapshot {
  final int schemaVersion;
  final int generation;
  final List<Map<String, Object?>> nodes;

  const CompositionSnapshot({
    required this.schemaVersion,
    required this.generation,
    required this.nodes,
  });
}

/// Storage contract for composition snapshots.
///
/// Implementations must replace a snapshot atomically: after [write] completes,
/// readers must observe either the previous complete snapshot or the new one.
abstract interface class CompositionSnapshotStore {
  Future<CompositionSnapshot?> read();
  Future<void> write(CompositionSnapshot snapshot);
  Future<void> clear();
}

/// Simple store for tests and ephemeral hosts. Production hosts can implement
/// [CompositionSnapshotStore] with preferences, SQLite, files, or a remote DB.
class InMemoryCompositionSnapshotStore implements CompositionSnapshotStore {
  CompositionSnapshot? _snapshot;

  @override
  Future<CompositionSnapshot?> read() async {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    return CompositionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      generation: snapshot.generation,
      nodes: snapshot.nodes.map(_copyMap).toList(growable: false),
    );
  }

  @override
  Future<void> write(CompositionSnapshot snapshot) async {
    _snapshot = CompositionSnapshot(
      schemaVersion: snapshot.schemaVersion,
      generation: snapshot.generation,
      nodes: snapshot.nodes.map(_copyMap).toList(growable: false),
    );
  }

  @override
  Future<void> clear() async => _snapshot = null;

  Map<String, Object?> _copyMap(Map<String, Object?> value) =>
      Map<String, Object?>.from(value);
}

/// Encodes and decodes the supported built-in composition node contracts.
class CompositionSnapshotCodec {
  static const int currentSchemaVersion = 1;

  CompositionSnapshot encode(
    CompositionPlan plan, {
    required int generation,
  }) {
    if (generation < 1) {
      throw ArgumentError.value(generation, 'generation', 'Must be positive.');
    }
    final nodes = plan.nodes.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return CompositionSnapshot(
      schemaVersion: currentSchemaVersion,
      generation: generation,
      nodes: nodes.map(_encodeNode).toList(growable: false),
    );
  }

  CompositionGraph decode(CompositionSnapshot snapshot) {
    if (snapshot.schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported composition snapshot schema '
        '${snapshot.schemaVersion}; expected $currentSchemaVersion.',
      );
    }
    if (snapshot.generation < 1) {
      throw const FormatException('Snapshot generation must be positive.');
    }

    final graph = CompositionGraph();
    try {
      graph.addAll(snapshot.nodes.map(_decodeNode));
    } on Object catch (error) {
      throw FormatException('Invalid composition snapshot: $error');
    }

    final diagnostics = graph.validate();
    if (diagnostics.isNotEmpty) {
      throw FormatException(
        'Snapshot composition is invalid: '
        '${diagnostics.map((item) => item.message).join('; ')}',
      );
    }
    return graph;
  }

  Map<String, Object?> _encodeNode(CompositionNode node) {
    final typeAndIdentity = switch (node) {
      CommandNode value => ('command', 'commandId', value.commandId),
      ViewNode value => ('view', 'viewId', value.viewId),
      UiContributionNode value =>
        ('contribution', 'contributionId', value.contributionId),
      ServiceNode value => ('service', 'serviceId', value.serviceId),
      ShellRegionNode value => ('region', 'regionId', value.regionId),
    };
    return <String, Object?>{
      'type': typeAndIdentity.$1,
      typeAndIdentity.$2: typeAndIdentity.$3,
      'id': node.id,
      'ownerId': node.ownerId,
      'phase': node.phase.name,
      'dependencies': (node.dependencies.toList()
            ..sort((a, b) => a.nodeId.compareTo(b.nodeId)))
          .map((dependency) => <String, Object?>{
                'nodeId': dependency.nodeId,
                'required': dependency.required,
              })
          .toList(growable: false),
      if (node is UiContributionNode) 'surfaceId': node.surfaceId,
    };
  }

  CompositionNode _decodeNode(Map<String, Object?> value) {
    String string(String key) {
      final item = value[key];
      if (item is! String || item.isEmpty) {
        throw FormatException('Expected non-empty string "$key".');
      }
      return item;
    }

    final type = string('type');
    final ownerId = string('ownerId');
    final phaseName = string('phase');
    final phase = CompositionPhase.values.where((item) => item.name == phaseName);
    if (phase.isEmpty) throw FormatException('Unknown composition phase "$phaseName".');

    final rawDependencies = value['dependencies'];
    if (rawDependencies is! List) {
      throw const FormatException('Expected dependencies to be a list.');
    }
    final dependencies = <CompositionDependency>{};
    for (final raw in rawDependencies) {
      if (raw is! Map) throw const FormatException('Invalid dependency entry.');
      final id = raw['nodeId'];
      final required = raw['required'];
      if (id is! String || id.isEmpty || required is! bool) {
        throw const FormatException('Invalid dependency fields.');
      }
      dependencies.add(CompositionDependency(id, required: required));
    }

    final node = switch (type) {
      'command' => CommandNode(
          commandId: string('commandId'),
          ownerId: ownerId,
          phase: phase.first,
          dependencies: dependencies,
        ),
      'view' => ViewNode(
          viewId: string('viewId'),
          ownerId: ownerId,
          phase: phase.first,
          dependencies: dependencies,
        ),
      'contribution' => UiContributionNode(
          contributionId: string('contributionId'),
          surfaceId: string('surfaceId'),
          ownerId: ownerId,
          phase: phase.first,
          dependencies: dependencies,
        ),
      'service' => ServiceNode(
          serviceId: string('serviceId'),
          ownerId: ownerId,
          phase: phase.first,
          dependencies: dependencies,
        ),
      'region' => ShellRegionNode(
          regionId: string('regionId'),
          ownerId: ownerId,
          phase: phase.first,
          dependencies: dependencies,
        ),
      _ => throw FormatException('Unknown composition node type "$type".'),
    };

    if (node.id != string('id')) {
      throw FormatException(
        'Node identity mismatch: encoded "${value['id']}", derived "${node.id}".',
      );
    }
    return node;
  }
}

/// Coordinates durable snapshots and validated graph reconstruction.
class CompositionPersistence {
  final CompositionSnapshotStore store;
  final CompositionSnapshotCodec codec;

  CompositionPersistence({
    required this.store,
    CompositionSnapshotCodec? codec,
  }) : codec = codec ?? CompositionSnapshotCodec();

  /// Persists [plan] as the next generation.
  ///
  /// The store's atomic-write contract prevents partially written snapshots.
  Future<CompositionSnapshot> save(CompositionPlan plan) async {
    final previous = await store.read();
    final generation = (previous?.generation ?? 0) + 1;
    final snapshot = codec.encode(plan, generation: generation);
    await store.write(snapshot);
    return snapshot;
  }

  /// Loads and validates the last snapshot, returning null when none exists.
  Future<CompositionPlan?> restore() async {
    final snapshot = await store.read();
    if (snapshot == null) return null;
    final graph = codec.decode(snapshot);
    return CompositionPlan.fromGraph(graph);
  }

  Future<void> clear() => store.clear();
}

/// JSON-friendly conversion helpers for durable adapters.
String encodeCompositionSnapshotJson(CompositionSnapshot snapshot) {
  return jsonEncode({
    'schemaVersion': snapshot.schemaVersion,
    'generation': snapshot.generation,
    'nodes': snapshot.nodes,
  });
}

CompositionSnapshot decodeCompositionSnapshotJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Composition snapshot must be a JSON object.');
  }
  final schemaVersion = decoded['schemaVersion'];
  final generation = decoded['generation'];
  final nodes = decoded['nodes'];
  if (schemaVersion is! int || generation is! int || nodes is! List) {
    throw const FormatException('Composition snapshot header is invalid.');
  }
  final typedNodes = <Map<String, Object?>>[];
  for (final node in nodes) {
    if (node is! Map) throw const FormatException('Snapshot node must be an object.');
    typedNodes.add(Map<String, Object?>.from(node));
  }
  return CompositionSnapshot(
    schemaVersion: schemaVersion,
    generation: generation,
    nodes: typedNodes,
  );
}

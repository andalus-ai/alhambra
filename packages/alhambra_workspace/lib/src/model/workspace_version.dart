import 'package:alhambra_core/alhambra_core.dart';

/// Represents an immutable point-in-time snapshot/version of a workspace.
final class WorkspaceVersion {
  final int number;
  final DateTime createdAt;
  final UserId actorId;
  final String description;

  const WorkspaceVersion({
    required this.number,
    required this.createdAt,
    required this.actorId,
    required this.description,
  });

  WorkspaceVersion next({
    required UserId actorId,
    required String description,
    DateTime? createdAt,
  }) {
    return WorkspaceVersion(
      number: number + 1,
      createdAt: createdAt ?? DateTime.now(),
      actorId: actorId,
      description: description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceVersion &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          createdAt == other.createdAt &&
          actorId == other.actorId &&
          description == other.description;

  @override
  int get hashCode => Object.hash(number, createdAt, actorId, description);

  @override
  String toString() =>
      'WorkspaceVersion(v$number, actor: $actorId, desc: $description)';
}

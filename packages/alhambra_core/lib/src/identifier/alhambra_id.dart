import 'package:meta/meta.dart';

/// Base identity abstraction for all entities, resources, and actors in Alhambra.
@immutable
class AlhambraId {
  final String value;

  const AlhambraId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlhambraId &&
          runtimeType == other.runtimeType &&
          other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Specialized identifier for Workspaces.
final class WorkspaceId extends AlhambraId {
  const WorkspaceId(super.value);
}

/// Specialized identifier for Users and Principals.
final class UserId extends AlhambraId {
  const UserId(super.value);
}

/// Specialized identifier for Organizations and Tenants.
final class OrganizationId extends AlhambraId {
  const OrganizationId(super.value);
}

/// Specialized identifier for Analysis runs.
final class AnalysisId extends AlhambraId {
  const AnalysisId(super.value);
}

/// Specialized identifier for Autonomous Execution loops.
final class ExecutionId extends AlhambraId {
  const ExecutionId(super.value);
}

/// Specialized identifier for Evidence nodes.
final class EvidenceId extends AlhambraId {
  const EvidenceId(super.value);
}

/// Specialized identifier for Artifacts.
final class ArtifactId extends AlhambraId {
  const ArtifactId(super.value);
}

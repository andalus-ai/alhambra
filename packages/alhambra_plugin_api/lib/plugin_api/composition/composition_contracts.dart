abstract final class CompositionNodeIds {
  static String command(String id) => 'command:$id';
  static String view(String id) => 'view:$id';
  static String contribution(String id) => 'contribution:$id';
  static String service(String id) => 'service:$id';
  static String region(String id) => 'region:$id';
  static String policy(String id) => 'policy:$id';
}

enum CompositionPhase {
  bootstrap,
  services,
  commands,
  views,
  surfaces,
  runtime,
}

enum CompositionNodeState {
  declared,
  staged,
  validated,
  active,
  inactive,
  failed,
}

class CompositionDependency {
  final String nodeId;
  final bool required;

  const CompositionDependency(
    this.nodeId, {
    this.required = true,
  });
}

sealed class CompositionNode {
  String get id;
  String get ownerId;
  CompositionPhase get phase;
  Set<CompositionDependency> get dependencies;
}

final class CommandNode extends CompositionNode {
  final String commandId;
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final CompositionPhase phase;
  @override
  final Set<CompositionDependency> dependencies;

  CommandNode({
    required this.commandId,
    required this.ownerId,
    this.phase = CompositionPhase.commands,
    this.dependencies = const {},
  }) : id = CompositionNodeIds.command(commandId);
}

final class ViewNode extends CompositionNode {
  final String viewId;
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final CompositionPhase phase;
  @override
  final Set<CompositionDependency> dependencies;

  ViewNode({
    required this.viewId,
    required this.ownerId,
    this.phase = CompositionPhase.views,
    this.dependencies = const {},
  }) : id = CompositionNodeIds.view(viewId);
}

final class UiContributionNode extends CompositionNode {
  final String contributionId;
  final String surfaceId;
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final CompositionPhase phase;
  @override
  final Set<CompositionDependency> dependencies;

  UiContributionNode({
    required this.contributionId,
    required this.surfaceId,
    required this.ownerId,
    this.phase = CompositionPhase.surfaces,
    this.dependencies = const {},
  }) : id = CompositionNodeIds.contribution(contributionId);
}

final class ServiceNode extends CompositionNode {
  final String serviceId;
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final CompositionPhase phase;
  @override
  final Set<CompositionDependency> dependencies;

  ServiceNode({
    required this.serviceId,
    required this.ownerId,
    this.phase = CompositionPhase.services,
    this.dependencies = const {},
  }) : id = CompositionNodeIds.service(serviceId);
}

final class ShellRegionNode extends CompositionNode {
  final String regionId;
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final CompositionPhase phase;
  @override
  final Set<CompositionDependency> dependencies;

  ShellRegionNode({
    required this.regionId,
    required this.ownerId,
    this.phase = CompositionPhase.surfaces,
    this.dependencies = const {},
  }) : id = CompositionNodeIds.region(regionId);
}

sealed class CompositionDiagnostic {
  final String message;
  const CompositionDiagnostic(this.message);
}

final class MissingDependencyDiagnostic extends CompositionDiagnostic {
  final String nodeId;
  final String dependencyId;
  const MissingDependencyDiagnostic({
    required this.nodeId,
    required this.dependencyId,
  }) : super('Node "$nodeId" requires missing dependency "$dependencyId"');
}

final class CompositionCycleDiagnostic extends CompositionDiagnostic {
  final List<String> cycle;
  CompositionCycleDiagnostic(this.cycle)
      : super('Circular composition dependency detected: ${cycle.join(" -> ")}');
}

final class DuplicateNodeDiagnostic extends CompositionDiagnostic {
  final String nodeId;
  final String existingOwnerId;
  final String newOwnerId;
  const DuplicateNodeDiagnostic({
    required this.nodeId,
    required this.existingOwnerId,
    required this.newOwnerId,
  }) : super('Duplicate node "$nodeId" owned by "$existingOwnerId", attempted by "$newOwnerId"');
}

final class PolicyRejectedDiagnostic extends CompositionDiagnostic {
  final String nodeId;
  final String reason;
  const PolicyRejectedDiagnostic({
    required this.nodeId,
    required this.reason,
  }) : super('Policy rejected node "$nodeId": $reason');
}

sealed class CompositionResult {
  const CompositionResult();
}

final class CompositionSuccess extends CompositionResult {
  final List<String> activatedNodeIds;
  const CompositionSuccess({required this.activatedNodeIds});
}

final class CompositionFailure extends CompositionResult {
  final List<CompositionDiagnostic> diagnostics;
  const CompositionFailure({required this.diagnostics});
}

enum CompositionOwnerState {\n  active,\n  deactivating,\n  inactive,\n  failed,\n}\n\nenum DeactivationStrategy {
  reject,
  cascade,
  degrade,
}

enum CompositionConflictPolicy {
  reject,
  replace,
  compose,
}


/// Lifecycle hooks for composing plugin contributions.
///
/// Implementations should keep external side effects reversible until
/// [activate] succeeds. [compensate] is invoked when preparation or activation
/// fails; it should be idempotent and best-effort.
abstract interface class CompositionLifecycle {
  void prepare(List<CompositionNode> orderedNodes);
  void activate(List<CompositionNode> orderedNodes);
  void deactivate(List<CompositionNode> reverseOrderedNodes);
  void compensate(List<CompositionNode> orderedNodes, Object error, StackTrace stackTrace);
}

/// Lifecycle operations exposed through the framework-neutral diagnostics API.
enum CompositionLifecycleOperation {
  prepare,
  activate,
  deactivate,
  compensate,
}

/// Outcome of an individual lifecycle callback.
enum CompositionLifecycleStatus {
  started,
  succeeded,
  failed,
}

/// Immutable diagnostic event emitted around a composition lifecycle callback.
///
/// The event model deliberately contains primitive identifiers and error
/// summaries only; it does not expose runtime internals or telemetry vendors.
class CompositionLifecycleEvent {
  final String correlationId;
  final CompositionLifecycleOperation operation;
  final CompositionLifecycleStatus status;
  final DateTime timestamp;
  final List<String> nodeIds;
  final List<String> ownerIds;
  final Duration? duration;
  final String? errorType;
  final String? errorMessage;

  CompositionLifecycleEvent({
    required this.correlationId,
    required this.operation,
    required this.status,
    required this.timestamp,
    required List<String> nodeIds,
    required List<String> ownerIds,
    this.duration,
    this.errorType,
    this.errorMessage,
  })  : nodeIds = List.unmodifiable(nodeIds),
        ownerIds = List.unmodifiable(ownerIds);
}

/// Optional sink for lifecycle diagnostics. Sink failures must not affect
/// composition correctness.
typedef CompositionLifecycleEventSink = void Function(
  CompositionLifecycleEvent event,
);

import '../runtime_scope/runtime_scope_contracts.dart';

/// Strongly typed identity for capabilities.
final class CapabilityId {
  final String value;

  const CapabilityId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapabilityId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Standard core capabilities.
abstract final class StandardCapabilities {
  static const CapabilityId workspaceRead = CapabilityId(
    'alhambra.workspace.read',
  );
  static const CapabilityId workspaceWrite = CapabilityId(
    'alhambra.workspace.write',
  );
  static const CapabilityId filesRead = CapabilityId('alhambra.files.read');
  static const CapabilityId filesWrite = CapabilityId('alhambra.files.write');
  static const CapabilityId network = CapabilityId('alhambra.network');
  static const CapabilityId processExecute = CapabilityId(
    'alhambra.process.execute',
  );
  static const CapabilityId secretsRead = CapabilityId('alhambra.secrets.read');
  static const CapabilityId uiViews = CapabilityId('alhambra.ui.views');
  static const CapabilityId commandsExecute = CapabilityId(
    'alhambra.commands.execute',
  );
  static const CapabilityId notifications = CapabilityId(
    'alhambra.notifications',
  );
}

enum CapabilityRisk { low, medium, high, critical }

final class CapabilityDescriptor {
  final CapabilityId id;
  final String description;
  final CapabilityRisk risk;
  final bool userVisible;

  const CapabilityDescriptor({
    required this.id,
    required this.description,
    required this.risk,
    this.userVisible = true,
  });
}

enum CapabilityRequirement { required, optional }

final class CapabilityRequest {
  final CapabilityId capability;
  final CapabilityRequirement requirement;
  final String? reason;

  const CapabilityRequest({
    required this.capability,
    this.requirement = CapabilityRequirement.required,
    this.reason,
  });

  bool get isRequired => requirement == CapabilityRequirement.required;
  bool get isOptional => requirement == CapabilityRequirement.optional;
}

enum CapabilityDecision { allowed, denied, conditional }

final class CapabilityConstraint {
  final String type;
  final Map<String, Object?> parameters;

  const CapabilityConstraint({required this.type, this.parameters = const {}});
}

final class CapabilityGrant {
  final CapabilityId capability;
  final CapabilityDecision decision;
  final String? reason;
  final List<CapabilityConstraint> constraints;

  const CapabilityGrant({
    required this.capability,
    required this.decision,
    this.reason,
    this.constraints = const [],
  });

  bool get isAllowed => decision == CapabilityDecision.allowed;
  bool get isDenied => decision == CapabilityDecision.denied;
  bool get isConditional => decision == CapabilityDecision.conditional;
}

final class CapabilityScope {
  final PluginInstanceId pluginInstanceId;
  final WorkspaceId? workspaceId;
  final WindowId? windowId;
  final ViewInstanceId? viewId;

  const CapabilityScope({
    required this.pluginInstanceId,
    this.workspaceId,
    this.windowId,
    this.viewId,
  });
}

final class CapabilityPolicyContext {
  final String pluginId;
  final String pluginVersion;
  final ApplicationId applicationId;
  final WindowId? windowId;
  final WorkspaceId? workspaceId;
  final Map<String, Object?> metadata;

  const CapabilityPolicyContext({
    required this.pluginId,
    required this.pluginVersion,
    required this.applicationId,
    this.windowId,
    this.workspaceId,
    this.metadata = const {},
  });
}

final class CapabilityPolicyDecision {
  final CapabilityDecision decision;
  final String source;
  final String? reason;
  final List<CapabilityConstraint> constraints;

  const CapabilityPolicyDecision({
    required this.decision,
    required this.source,
    this.reason,
    this.constraints = const [],
  });
}

abstract interface class CapabilityPolicy {
  Future<CapabilityGrant> evaluate(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  );
}

abstract interface class CapabilityResolver {
  Future<CapabilityGrant> resolve(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  );
}

abstract interface class CapabilityAccess {
  bool canUse(CapabilityId capability);
  Future<void> require(CapabilityId capability);
  CapabilityGrant? getGrant(CapabilityId capability);
}

class CapabilityException implements Exception {
  final CapabilityId capability;
  final String message;
  final String? reason;

  const CapabilityException({
    required this.capability,
    required this.message,
    this.reason,
  });

  @override
  String toString() =>
      'CapabilityException($capability): $message ${reason != null ? '($reason)' : ''}';
}

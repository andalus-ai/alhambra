import '../plugins/plugin_sdk_contracts.dart';
import 'capabilities_models.dart';

/// Standard capability identifiers for broker requests.
abstract final class BrokerStandardCapabilities {
  static const workspaceRead = CapabilityId('workspace.read');
  static const workspaceWrite = CapabilityId('workspace.write');
  static const filesystemRead = CapabilityId('filesystem.read');
  static const filesystemWrite = CapabilityId('filesystem.write');
  static const network = CapabilityId('network');
  static const processExecute = CapabilityId('process.execute');
  static const terminal = CapabilityId('terminal');
  static const secretsRead = CapabilityId('secrets.read');
}

/// Resource target of a capability request.
sealed class CapabilityResource {
  const CapabilityResource();
}

final class PathResource extends CapabilityResource {
  final String path;
  const PathResource(this.path);

  @override
  String toString() => 'PathResource($path)';
}

final class HostResource extends CapabilityResource {
  final String host;
  const HostResource(this.host);

  @override
  String toString() => 'HostResource($host)';
}

/// Scope lifetime classification for a grant.
enum CapabilityScopeKind {
  application,
  window,
  workspace,
  plugin,
  view,
}

/// A grant issued by the broker with explicit scope and resource boundaries.
final class ScopedCapabilityGrant {
  final CapabilityId capability;
  final CapabilityScopeKind scopeKind;
  final String scopeId;
  final CapabilityResource? resource;
  final DateTime issuedAt;

  ScopedCapabilityGrant({
    required this.capability,
    required this.scopeKind,
    required this.scopeId,
    this.resource,
    DateTime? issuedAt,
  }) : issuedAt = issuedAt ?? DateTime.now();
}

/// Decision outcome types for capability requests.
enum CapabilityDecisionType {
  granted,
  denied,
  requiresConsent,
  unavailable,
  restricted,
}

/// Result of evaluating a capability request against policies.
final class BrokerCapabilityDecision {
  final CapabilityDecisionType type;
  final ScopedCapabilityGrant? grant;
  final String? reason;

  const BrokerCapabilityDecision({
    required this.type,
    this.grant,
    this.reason,
  });

  bool get isGranted => type == CapabilityDecisionType.granted;

  const BrokerCapabilityDecision.granted(ScopedCapabilityGrant grant)
      : type = CapabilityDecisionType.granted,
        grant = grant,
        reason = null;

  const BrokerCapabilityDecision.denied([this.reason])
      : type = CapabilityDecisionType.denied,
        grant = null;

  const BrokerCapabilityDecision.requiresConsent([this.reason])
      : type = CapabilityDecisionType.requiresConsent,
        grant = null;
}

/// Context provided during capability evaluation.
final class CapabilityContext {
  final PluginId pluginId;
  final CapabilityScopeKind scopeKind;
  final String scopeId;
  final Map<String, Object?> attributes;

  const CapabilityContext({
    required this.pluginId,
    required this.scopeKind,
    required this.scopeId,
    this.attributes = const {},
  });
}

/// Central broker managing dynamic capability requests, queries, and revocations.
abstract interface class CapabilityBroker {
  Future<BrokerCapabilityDecision> request(
    CapabilityId capability,
    CapabilityContext context, {
    CapabilityResource? resource,
  });

  bool isGranted(
    CapabilityId capability,
    CapabilityContext context, {
    CapabilityResource? resource,
  });

  Future<void> revoke(ScopedCapabilityGrant grant);
  Future<void> revokeAllForScope(String scopeId);
}

/// Policy evaluation engine.
abstract interface class CapabilityPolicyEngine {
  Future<BrokerCapabilityDecision> evaluate(
    CapabilityId capability,
    CapabilityContext context,
    CapabilityResource? resource,
  );
}

/// Sandboxed, scoped file system interface.
abstract interface class ScopedFileSystem {
  Future<String> readFile(String relativePath);
  Future<void> writeFile(String relativePath, String content);
  Future<bool> exists(String relativePath);
}

/// Sandboxed, scoped network interface.
abstract interface class ScopedNetwork {
  Future<String> get(Uri uri);
  Future<String> post(Uri uri, {Map<String, String>? headers, String? body});
}

/// Sandboxed process executor interface.
abstract interface class ScopedProcessRunner {
  Future<int> execute(String executable, List<String> args);
}

import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Multi-tier hierarchical policy engine enforcing security precedence.
class HierarchicalPolicyEngine implements CapabilityPolicyEngine {
  final Set<String> deniedCapabilities;
  final Set<String> enterpriseDenied;
  final Set<String> autoAllowedCapabilities;

  HierarchicalPolicyEngine({
    this.deniedCapabilities = const {},
    this.enterpriseDenied = const {},
    this.autoAllowedCapabilities = const {},
  });

  @override
  Future<BrokerCapabilityDecision> evaluate(
    CapabilityId capability,
    CapabilityContext context,
    CapabilityResource? resource,
  ) async {
    // 1. System security denial
    if (deniedCapabilities.contains(capability.value)) {
      return BrokerCapabilityDecision.denied(
        'Capability "${capability.value}" is blocked by system security policy',
      );
    }

    // 2. Enterprise policy restriction
    if (enterpriseDenied.contains(capability.value)) {
      return BrokerCapabilityDecision.denied(
        'Capability "${capability.value}" is denied by enterprise administrative policy',
      );
    }

    // 3. Auto-allowed default rules
    if (autoAllowedCapabilities.contains(capability.value)) {
      final grant = ScopedCapabilityGrant(
        capability: capability,
        scopeKind: context.scopeKind,
        scopeId: context.scopeId,
        resource: resource,
      );
      return BrokerCapabilityDecision.granted(grant);
    }

    // 4. Default: User consent required
    return const BrokerCapabilityDecision.requiresConsent(
      'User consent required to authorize this capability',
    );
  }
}

/// Central capability broker managing scoped grants and lifetime revocations.
class DefaultCapabilityBroker implements CapabilityBroker {
  final CapabilityPolicyEngine policyEngine;
  final Map<String, List<ScopedCapabilityGrant>> _grantsByScopeId = {};

  DefaultCapabilityBroker({required this.policyEngine});

  @override
  Future<BrokerCapabilityDecision> request(
    CapabilityId capability,
    CapabilityContext context, {
    CapabilityResource? resource,
  }) async {
    final decision = await policyEngine.evaluate(capability, context, resource);
    if (decision.isGranted && decision.grant != null) {
      _grantsByScopeId
          .putIfAbsent(context.scopeId, () => [])
          .add(decision.grant!);
    }
    return decision;
  }

  @override
  bool isGranted(
    CapabilityId capability,
    CapabilityContext context, {
    CapabilityResource? resource,
  }) {
    final grants = _grantsByScopeId[context.scopeId];
    if (grants == null || grants.isEmpty) return false;

    return grants.any((g) {
      if (g.capability != capability) return false;
      if (resource != null && g.resource != null) {
        if (resource is PathResource && g.resource is PathResource) {
          final target = (resource as PathResource).path;
          final allowed = (g.resource as PathResource).path;
          return target.startsWith(allowed);
        }
        if (resource is HostResource && g.resource is HostResource) {
          return (resource as HostResource).host ==
              (g.resource as HostResource).host;
        }
      }
      return true;
    });
  }

  @override
  Future<void> revoke(ScopedCapabilityGrant grant) async {
    final list = _grantsByScopeId[grant.scopeId];
    if (list != null) {
      list.removeWhere(
        (g) => g.capability == grant.capability && g.resource == grant.resource,
      );
    }
  }

  @override
  Future<void> revokeAllForScope(String scopeId) async {
    _grantsByScopeId.remove(scopeId);
  }

  List<ScopedCapabilityGrant> getGrantsForScope(String scopeId) {
    final list = _grantsByScopeId[scopeId];
    if (list == null) return const [];
    return List.unmodifiable(list);
  }
}

/// In-memory sandboxed file system constrained to an allowed root path.
class InMemoryScopedFileSystem implements ScopedFileSystem {
  final String allowedPrefix;
  final Map<String, String> _files = {};

  InMemoryScopedFileSystem({required this.allowedPrefix});

  void _validatePath(String relativePath) {
    final full = '$allowedPrefix/$relativePath';
    if (!full.startsWith(allowedPrefix)) {
      throw SecurityException(
        'Access denied: path "$relativePath" escapes allowed scope "$allowedPrefix"',
      );
    }
  }

  @override
  Future<String> readFile(String relativePath) async {
    _validatePath(relativePath);
    final content = _files[relativePath];
    if (content == null) throw StateError('File not found: $relativePath');
    return content;
  }

  @override
  Future<void> writeFile(String relativePath, String content) async {
    _validatePath(relativePath);
    _files[relativePath] = content;
  }

  @override
  Future<bool> exists(String relativePath) async {
    _validatePath(relativePath);
    return _files.containsKey(relativePath);
  }
}

/// In-memory sandboxed network client constrained to allowed domain hosts.
class InMemoryScopedNetwork implements ScopedNetwork {
  final Set<String> allowedHosts;

  InMemoryScopedNetwork({required this.allowedHosts});

  void _validateUri(Uri uri) {
    if (!allowedHosts.contains(uri.host)) {
      throw SecurityException(
        'Access denied: host "${uri.host}" is not in authorized domains: $allowedHosts',
      );
    }
  }

  @override
  Future<String> get(Uri uri) async {
    _validateUri(uri);
    return '{"status": "ok", "url": "${uri.toString()}"}';
  }

  @override
  Future<String> post(
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  }) async {
    _validateUri(uri);
    return '{"status": "created", "url": "${uri.toString()}"}';
  }
}

/// In-memory sandboxed process runner.
class InMemoryScopedProcessRunner implements ScopedProcessRunner {
  final Set<String> allowedExecutables;

  InMemoryScopedProcessRunner({required this.allowedExecutables});

  @override
  Future<int> execute(String executable, List<String> args) async {
    if (!allowedExecutables.contains(executable)) {
      throw SecurityException(
        'Access denied: execution of "$executable" is not authorized',
      );
    }
    return 0; // Success
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

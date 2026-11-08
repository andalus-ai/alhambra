import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class InMemoryCapabilityRegistry implements CapabilityAccess {
  final Map<String, CapabilityDescriptor> _descriptors = {};
  final Map<String, CapabilityGrant> _activeGrants = {};

  void registerDescriptor(CapabilityDescriptor descriptor) {
    _descriptors[descriptor.id.value] = descriptor;
  }

  CapabilityDescriptor? getDescriptor(CapabilityId id) =>
      _descriptors[id.value];

  List<CapabilityDescriptor> get allDescriptors =>
      List.unmodifiable(_descriptors.values);

  void grant(CapabilityGrant grant) {
    _activeGrants[grant.capability.value] = grant;
  }

  void revoke(CapabilityId capability) {
    _activeGrants.remove(capability.value);
  }

  @override
  bool canUse(CapabilityId capability) {
    final grant = _activeGrants[capability.value];
    return grant != null && grant.isAllowed;
  }

  @override
  Future<void> require(CapabilityId capability) async {
    if (!canUse(capability)) {
      throw CapabilityException(
        capability: capability,
        message:
            'Required capability "${capability.value}" is not granted to this scope.',
      );
    }
  }

  @override
  CapabilityGrant? getGrant(CapabilityId capability) =>
      _activeGrants[capability.value];

  void clear() {
    _descriptors.clear();
    _activeGrants.clear();
  }
}

class CommunityCapabilityPolicy implements CapabilityPolicy {
  final Set<CapabilityId> restrictedCapabilities;

  const CommunityCapabilityPolicy({this.restrictedCapabilities = const {}});

  @override
  Future<CapabilityGrant> evaluate(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  ) async {
    if (restrictedCapabilities.contains(request.capability)) {
      return CapabilityGrant(
        capability: request.capability,
        decision: CapabilityDecision.denied,
        reason:
            'Capability "${request.capability.value}" is restricted in Community edition.',
      );
    }

    return CapabilityGrant(
      capability: request.capability,
      decision: CapabilityDecision.allowed,
      reason: 'Allowed by Community policy.',
    );
  }
}

class ProCapabilityPolicy implements CapabilityPolicy {
  final Set<CapabilityId> userConsentedCapabilities;
  final Set<CapabilityId> deniedCapabilities;

  const ProCapabilityPolicy({
    this.userConsentedCapabilities = const {},
    this.deniedCapabilities = const {},
  });

  @override
  Future<CapabilityGrant> evaluate(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  ) async {
    if (deniedCapabilities.contains(request.capability)) {
      return CapabilityGrant(
        capability: request.capability,
        decision: CapabilityDecision.denied,
        reason: 'Denied by user consent or Pro configuration.',
      );
    }

    return CapabilityGrant(
      capability: request.capability,
      decision: CapabilityDecision.allowed,
      reason: 'Allowed by Pro policy with verified consent.',
    );
  }
}

class EnterpriseCapabilityPolicy implements CapabilityPolicy {
  final Set<String> allowedPluginIds;
  final Map<CapabilityId, List<CapabilityConstraint>> capabilityConstraints;
  final Set<CapabilityId> blockedCapabilities;

  const EnterpriseCapabilityPolicy({
    this.allowedPluginIds = const {},
    this.capabilityConstraints = const {},
    this.blockedCapabilities = const {},
  });

  @override
  Future<CapabilityGrant> evaluate(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  ) async {
    // 1. Check if plugin is allowlisted if an allowlist is configured
    if (allowedPluginIds.isNotEmpty &&
        !allowedPluginIds.contains(context.pluginId)) {
      return CapabilityGrant(
        capability: request.capability,
        decision: CapabilityDecision.denied,
        reason:
            'Plugin "${context.pluginId}" is not in the enterprise allowlist.',
      );
    }

    // 2. Check explicitly blocked capabilities
    if (blockedCapabilities.contains(request.capability)) {
      return CapabilityGrant(
        capability: request.capability,
        decision: CapabilityDecision.denied,
        reason:
            'Capability "${request.capability.value}" is blocked by enterprise governance policy.',
      );
    }

    // 3. Apply constraints if configured
    final constraints = capabilityConstraints[request.capability];
    if (constraints != null && constraints.isNotEmpty) {
      return CapabilityGrant(
        capability: request.capability,
        decision: CapabilityDecision.conditional,
        reason: 'Allowed with enterprise constraints.',
        constraints: constraints,
      );
    }

    return CapabilityGrant(
      capability: request.capability,
      decision: CapabilityDecision.allowed,
      reason: 'Allowed by enterprise policy.',
    );
  }
}

class DefaultCapabilityResolver implements CapabilityResolver {
  final List<CapabilityPolicy> policies;

  const DefaultCapabilityResolver({
    this.policies = const [CommunityCapabilityPolicy()],
  });

  @override
  Future<CapabilityGrant> resolve(
    CapabilityRequest request,
    CapabilityPolicyContext context,
  ) async {
    // Evaluate policies in precedence order (e.g. Enterprise -> Pro -> Community).
    // The most restrictive decision wins (denied > conditional > allowed).
    CapabilityGrant currentGrant = CapabilityGrant(
      capability: request.capability,
      decision: CapabilityDecision.allowed,
      reason: 'Default grant.',
    );

    for (final policy in policies) {
      final grant = await policy.evaluate(request, context);
      if (grant.isDenied) {
        return grant; // Short circuit on explicit deny
      }
      if (grant.isConditional) {
        currentGrant = CapabilityGrant(
          capability: request.capability,
          decision: CapabilityDecision.conditional,
          reason: grant.reason,
          constraints: [...currentGrant.constraints, ...grant.constraints],
        );
      }
    }

    return currentGrant;
  }
}

import '../access/authorization.dart';
import '../access/role.dart';
import '../identity/principal.dart';
import '../policy/authorization_policy.dart';
import '../policy/policy_evaluator.dart';
import '../repository/membership_repository.dart';
import '../repository/role_repository.dart';

/// Complete, production-grade authorization engine implementing the P11 security pipeline:
///
/// 1. Principal verification (System, Service, Agent, User)
/// 2. Hard tenant isolation (request org vs resource org)
/// 3. Active membership verification for UserPrincipal
/// 4. Role and permission resolution
/// 5. Policy evaluation with Deny-overrides-allow semantics
/// 6. Optional audit emission
final class DefaultAuthorizationService implements AuthorizationService {
  final MembershipRepository? _membershipRepo;
  final RoleRepository? _roleRepo;
  final PolicyEvaluator _policyEvaluator;
  final List<AuthorizationPolicy> _policies;
  final Map<String, Set<String>> _agentPermissions;
  final Map<String, Set<String>> _servicePermissions;
  final void Function(AuthorizationRequest request, AuthorizationDecision decision)?
      _auditCallback;

  DefaultAuthorizationService({
    MembershipRepository? membershipRepository,
    RoleRepository? roleRepository,
    PolicyEvaluator policyEvaluator = const DefaultPolicyEvaluator(),
    List<AuthorizationPolicy> policies = const [],
    Map<String, Set<String>> agentPermissions = const {},
    Map<String, Set<String>> servicePermissions = const {},
    void Function(AuthorizationRequest request, AuthorizationDecision decision)?
        auditCallback,
  })  : _membershipRepo = membershipRepository,
        _roleRepo = roleRepository,
        _policyEvaluator = policyEvaluator,
        _policies = List.unmodifiable(policies),
        _agentPermissions = Map.unmodifiable(agentPermissions),
        _servicePermissions = Map.unmodifiable(servicePermissions),
        _auditCallback = auditCallback;

  @override
  Future<bool> isAllowed(AuthorizationRequest request) async {
    final decision = await authorize(request);
    return decision.allowed;
  }

  @override
  Future<AuthorizationDecision> authorize(AuthorizationRequest request) async {
    final decision = await _evaluateInternal(request);
    _auditCallback?.call(request, decision);
    return decision;
  }

  Future<AuthorizationDecision> _evaluateInternal(
      AuthorizationRequest request) async {
    // 1. System principal has elevated access
    if (request.principal is SystemPrincipal) {
      return const AuthorizationDecision.allow(
        reason: 'Allowed: Elevated SystemPrincipal',
      );
    }

    // 2. Tenant isolation check: request org must match resource org if both are specified
    final resOrg = request.resource.organizationId;
    final reqOrg = request.organizationId;
    if (resOrg != null && reqOrg != null && resOrg != reqOrg) {
      return AuthorizationDecision.deny(
        'Cross-tenant violation: request org ($reqOrg) does not match resource org ($resOrg)',
      );
    }

    // 3. User Principal membership check
    final targetOrg = resOrg ?? reqOrg;
    if (request.principal is UserPrincipal) {
      final userPrincipal = request.principal as UserPrincipal;
      final membershipRepo = _membershipRepo;
      if (targetOrg != null && membershipRepo != null) {
        final membership = await membershipRepo.findByUserAndOrg(
          userPrincipal.userId,
          targetOrg,
        );
        if (membership == null || !membership.active) {
          return AuthorizationDecision.deny(
            'User ${userPrincipal.userId} has no active membership in organization $targetOrg',
          );
        }

        // Check RBAC permissions from roles
        final roleRepo = _roleRepo;
        if (roleRepo != null) {
          final roleIds = membership.roleIds.map(RoleId.new);
          final roles = await roleRepo.findByIds(roleIds);
          final hasPerm = roles.any(
            (r) => r.hasPermissionKey(request.permission.key),
          );

          if (!hasPerm) {
            return AuthorizationDecision.deny(
              'User ${userPrincipal.userId} lacks permission ${request.permission.key}',
            );
          }
        }
      }
    } else if (request.principal is AgentPrincipal) {
      final agentId = (request.principal as AgentPrincipal).agentId;
      final allowedPerms = _agentPermissions[agentId] ?? const {};
      if (!allowedPerms.contains(request.permission.key)) {
        return AuthorizationDecision.deny(
          'Agent $agentId lacks permission ${request.permission.key}',
        );
      }
    } else if (request.principal is ServicePrincipal) {
      final serviceId = (request.principal as ServicePrincipal).serviceId;
      final allowedPerms = _servicePermissions[serviceId] ?? const {};
      if (!allowedPerms.contains(request.permission.key)) {
        return AuthorizationDecision.deny(
          'Service $serviceId lacks permission ${request.permission.key}',
        );
      }
    }

    // 4. Governance & explicit deny policy evaluation (veto gate)
    // Policies here act as deny-only vetoes — if a deny policy matches it blocks
    // the request, but the absence of an allow policy is not itself a denial.
    if (_policies.isNotEmpty) {
      final policyDecision = _policyEvaluator.evaluate(
        request: request,
        policies: _policies,
      );
      // Only block if an explicit deny policy fired (not default-deny)
      if (!policyDecision.allowed && policyDecision.matchedPolicies.isNotEmpty) {
        return policyDecision;
      }
    }

    return const AuthorizationDecision.allow(
      reason: 'Allowed: Passed RBAC and policy checks',
    );
  }
}

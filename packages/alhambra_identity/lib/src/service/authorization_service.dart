import '../access/authorization.dart';
import '../access/role.dart';
import '../identity/principal.dart';
import '../policy/authorization_policy.dart';
import '../policy/policy_evaluator.dart';
import '../repository/membership_repository.dart';
import '../repository/role_repository.dart';

/// Deny-by-default authorization engine.
///
/// User access requires an explicit organization context, active membership,
/// configured membership and role repositories, and a matching role permission.
/// Agent, service, and system principals require explicit permission allowlists.
/// Optional policies are deny-only vetoes; they do not replace the permission
/// checks above. Configure [requireAudit] when every decision must be persisted
/// by a host-provided [AuthorizationAuditSink].
final class DefaultAuthorizationService implements AuthorizationService {
  final MembershipRepository? _membershipRepo;
  final RoleRepository? _roleRepo;
  final PolicyEvaluator _policyEvaluator;
  final List<AuthorizationPolicy> _policies;
  final Map<String, Set<String>> _agentPermissions;
  final Map<String, Set<String>> _servicePermissions;
  final Set<String> _systemPermissions;
  final AuthorizationAuditSink? _auditSink;
  final bool _requireAudit;

  /// Legacy synchronous notification. This callback is not a durable audit
  /// guarantee; prefer [auditSink] for production audit persistence.
  final void Function(AuthorizationRequest request, AuthorizationDecision decision)?
      _auditCallback;

  DefaultAuthorizationService({
    MembershipRepository? membershipRepository,
    RoleRepository? roleRepository,
    PolicyEvaluator policyEvaluator = const DefaultPolicyEvaluator(),
    List<AuthorizationPolicy> policies = const [],
    Map<String, Set<String>> agentPermissions = const {},
    Map<String, Set<String>> servicePermissions = const {},
    Set<String> systemPermissions = const {},
    AuthorizationAuditSink? auditSink,
    bool requireAudit = false,
    @Deprecated('Use auditSink for an awaitable audit persistence contract.')
    void Function(AuthorizationRequest request, AuthorizationDecision decision)?
        auditCallback,
  })  : _membershipRepo = membershipRepository,
        _roleRepo = roleRepository,
        _policyEvaluator = policyEvaluator,
        _policies = List.unmodifiable(policies),
        _agentPermissions = Map.unmodifiable(agentPermissions.map(
          (key, value) => MapEntry(key, Set<String>.unmodifiable(value)),
        )),
        _servicePermissions = Map.unmodifiable(servicePermissions.map(
          (key, value) => MapEntry(key, Set<String>.unmodifiable(value)),
        )),
        _systemPermissions = Set.unmodifiable(systemPermissions),
        _auditSink = auditSink,
        _requireAudit = requireAudit,
        _auditCallback = auditCallback {
    if (auditSink != null && auditCallback != null) {
      throw ArgumentError('Configure auditSink or auditCallback, not both.');
    }
  }

  @override
  Future<bool> isAllowed(AuthorizationRequest request) async {
    final decision = await authorize(request);
    return decision.allowed;
  }

  @override
  Future<AuthorizationDecision> authorize(AuthorizationRequest request) async {
    final decision = await _evaluateInternal(request);
    final sink = _auditSink;

    if (_requireAudit && sink == null) {
      return const AuthorizationDecision.deny(
        'Required authorization audit sink is not configured',
      );
    }

    if (sink != null) {
      try {
        await sink.record(request, decision);
      } catch (_) {
        if (_requireAudit) {
          return const AuthorizationDecision.deny(
            'Required authorization audit persistence failed',
          );
        }
      }
    }

    _auditCallback?.call(request, decision);
    return decision;
  }

  Future<AuthorizationDecision> _evaluateInternal(
    AuthorizationRequest request,
  ) async {
    // Tenant-bound resources require an explicit matching request scope.
    final resourceOrg = request.resource.organizationId;
    final requestOrg = request.organizationId;
    if (resourceOrg != null && requestOrg != resourceOrg) {
      return AuthorizationDecision.deny(
        'Organization scope mismatch: request org (' +
            requestOrg.toString() +
            ') does not match resource org (' +
            resourceOrg.toString() +
            ')',
      );
    }

    switch (request.principal) {
      case UserPrincipal(:final userId):
        if (requestOrg == null) {
          return const AuthorizationDecision.deny(
            'User authorization requires an explicit organization scope',
          );
        }

        final membershipRepo = _membershipRepo;
        if (membershipRepo == null) {
          return const AuthorizationDecision.deny(
            'Membership repository is not configured',
          );
        }

        final membership = await membershipRepo.findByUserAndOrg(
          userId,
          requestOrg,
        );
        if (membership == null || !membership.active) {
          return AuthorizationDecision.deny(
            'User ' +
                userId.toString() +
                ' has no active membership in organization ' +
                requestOrg.toString(),
          );
        }

        final roleRepo = _roleRepo;
        if (roleRepo == null) {
          return const AuthorizationDecision.deny(
            'Role repository is not configured',
          );
        }

        final roleIds = membership.roleIds.map(RoleId.new);
        final roles = await roleRepo.findByIds(roleIds);
        final hasPermission = roles.any(
          (role) => role.hasPermissionKey(request.permission.key),
        );
        if (!hasPermission) {
          return AuthorizationDecision.deny(
            'User ' +
                userId.toString() +
                ' lacks permission ' +
                request.permission.key,
          );
        }

      case AgentPrincipal(:final agentId):
        final allowed = _agentPermissions[agentId] ?? const <String>{};
        if (!allowed.contains(request.permission.key)) {
          return AuthorizationDecision.deny(
            'Agent ' + agentId + ' lacks permission ' + request.permission.key,
          );
        }

      case ServicePrincipal(:final serviceId):
        final allowed = _servicePermissions[serviceId] ?? const <String>{};
        if (!allowed.contains(request.permission.key)) {
          return AuthorizationDecision.deny(
            'Service ' +
                serviceId +
                ' lacks permission ' +
                request.permission.key,
          );
        }

      case SystemPrincipal():
        if (!_systemPermissions.contains(request.permission.key)) {
          return AuthorizationDecision.deny(
            'System principal lacks explicitly configured permission ' +
                request.permission.key,
          );
        }
    }

    // Policies are optional deny-only vetoes. A policy allow cannot grant
    // permission that the principal did not already possess.
    if (_policies.isNotEmpty) {
      final policyDecision = _policyEvaluator.evaluate(
        request: request,
        policies: _policies,
      );
      if (!policyDecision.allowed &&
          policyDecision.matchedPolicies.isNotEmpty) {
        return policyDecision;
      }
    }

    return const AuthorizationDecision.allow(
      reason: 'Allowed: explicit principal permission and policy checks passed',
    );
  }
}

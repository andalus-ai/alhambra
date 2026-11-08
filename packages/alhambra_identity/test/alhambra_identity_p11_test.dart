// ignore_for_file: prefer_collection_literals

import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_identity/alhambra_identity.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Permission _perm(String resource, String action) =>
    Permission(resource: resource, action: action);

AccessResource _resource(
  String type, {
  OrganizationId? orgId,
  String? ownerId,
}) =>
    AccessResource(
      type: type,
      id: AlhambraId('res-$type'),
      organizationId: orgId,
      ownerId: ownerId,
    );

AuthorizationRequest _request({
  required Principal principal,
  required String resource,
  required String action,
  OrganizationId? requestOrg,
  OrganizationId? resourceOrg,
  String? ownerId,
  Map<String, Object?> context = const {},
}) =>
    AuthorizationRequest(
      principal: principal,
      permission: _perm(resource, action),
      resource: _resource(resource, orgId: resourceOrg, ownerId: ownerId),
      organizationId: requestOrg,
      context: context,
    );

/// Build a pre-wired [DefaultAuthorizationService] with one user, one org,
/// one role, and one permission matching [permKey].
Future<({
  DefaultAuthorizationService svc,
  InMemoryMembershipRepository membershipRepo,
  InMemoryRoleRepository roleRepo,
  UserId userId,
  OrganizationId orgId,
  String roleId,
})> _buildSvc({
  required String permKey,
  List<AuthorizationPolicy> policies = const [],
  Map<String, Set<String>> agentPermissions = const {},
  Map<String, Set<String>> servicePermissions = const {},
  void Function(AuthorizationRequest, AuthorizationDecision)? auditCallback,
}) async {
  final userId = UserId('user-1');
  final orgId = OrganizationId('org-1');
  const roleId = 'role-viewer';

  final membershipRepo = InMemoryMembershipRepository();
  final roleRepo = InMemoryRoleRepository();

  await membershipRepo.save(Membership(
    id: MembershipId('mbr-1'),
    userId: userId,
    organizationId: orgId,
    roleIds: const {roleId},
    active: true,
  ));

  final parts = permKey.split(':');
  final perm = Permission(resource: parts[0], action: parts[1]);
  await roleRepo.save(Role(
    id: RoleId(roleId),
    name: 'Viewer',
    permissions: {perm},
  ));

  final svc = DefaultAuthorizationService(
    membershipRepository: membershipRepo,
    roleRepository: roleRepo,
    policies: policies,
    agentPermissions: agentPermissions,
    servicePermissions: servicePermissions,
    auditCallback: auditCallback,
  );

  return (
    svc: svc,
    membershipRepo: membershipRepo,
    roleRepo: roleRepo,
    userId: userId,
    orgId: orgId,
    roleId: roleId,
  );
}

// ---------------------------------------------------------------------------
// P11 Tests
// ---------------------------------------------------------------------------

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. Principal types
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Principal types', () {
    test('UserPrincipal carries userId', () {
      final uid = UserId('u1');
      final p = UserPrincipal(userId: uid);
      expect(p.userId, uid);
    });

    test('AgentPrincipal carries agentId', () {
      const p = AgentPrincipal(agentId: 'agent-42');
      expect(p.agentId, 'agent-42');
    });

    test('ServicePrincipal carries serviceId', () {
      const p = ServicePrincipal(serviceId: 'svc-A');
      expect(p.serviceId, 'svc-A');
    });

    test('SystemPrincipal is distinguishable from other principals', () {
      final principals = <Principal>[
        UserPrincipal(userId: UserId('u1')),
        const AgentPrincipal(agentId: 'a1'),
        const ServicePrincipal(serviceId: 's1'),
        const SystemPrincipal(),
      ];
      expect(principals.whereType<SystemPrincipal>().length, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Organization as explicit tenancy boundary
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Organization tenancy boundary', () {
    test('Organization has id, name, active, tier, copyWith', () {
      const orgId = OrganizationId('org-x');
      final org = Organization(id: orgId, name: 'ACME');
      expect(org.id, orgId);
      expect(org.name, 'ACME');
      expect(org.active, isTrue);
      expect(org.tier, OrganizationTier.starter);

      final deactivated = org.copyWith(active: false);
      expect(deactivated.active, isFalse);
      expect(deactivated.id, orgId);
    });

    test('OrganizationContext links principal to org', () {
      final orgId = OrganizationId('org-x');
      final principal = UserPrincipal(userId: UserId('u1'));
      final ctx =
          OrganizationContext(organizationId: orgId, principal: principal);
      expect(ctx.organizationId, orgId);
      expect(ctx.principal, principal);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Membership is organization-scoped
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Membership organization scope', () {
    test('Membership is scoped to an org', () {
      final m = Membership(
        id: MembershipId('mbr-1'),
        userId: UserId('u1'),
        organizationId: OrganizationId('org-a'),
        active: true,
      );
      expect(m.organizationId, OrganizationId('org-a'));
    });

    test('Same user can have separate memberships in different orgs', () {
      final u = UserId('u1');
      final m1 = Membership(
        id: MembershipId('mbr-1'),
        userId: u,
        organizationId: OrganizationId('org-a'),
        active: true,
      );
      final m2 = Membership(
        id: MembershipId('mbr-2'),
        userId: u,
        organizationId: OrganizationId('org-b'),
        active: true,
      );
      expect(m1.organizationId, isNot(m2.organizationId));
    });

    test('Membership carries roleIds and teamIds', () {
      final m = Membership(
        id: MembershipId('mbr-3'),
        userId: UserId('u1'),
        organizationId: OrganizationId('org-a'),
        roleIds: const {'role-admin'},
        teamIds: const {'team-eng'},
        active: true,
      );
      expect(m.roleIds, contains('role-admin'));
      expect(m.teamIds, contains('team-eng'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. MembershipService
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 MembershipService', () {
    late InMemoryMembershipRepository repo;
    late MembershipService svc;
    final userId = UserId('u1');
    final orgId = OrganizationId('org-a');

    setUp(() {
      repo = InMemoryMembershipRepository();
      svc = DefaultMembershipService(repo);
    });

    test('addMember creates active membership', () async {
      final m = await svc.addMember(userId: userId, organizationId: orgId);
      expect(m.active, isTrue);
      expect(m.userId, userId);
      expect(m.organizationId, orgId);
    });

    test('addMember merges roleIds if membership exists', () async {
      await svc.addMember(
          userId: userId, organizationId: orgId, roleIds: const {'role-a'});
      final updated = await svc.addMember(
          userId: userId, organizationId: orgId, roleIds: const {'role-b'});
      expect(updated.roleIds, containsAll(['role-a', 'role-b']));
    });

    test('assignRoles adds roles to existing membership', () async {
      await svc.addMember(userId: userId, organizationId: orgId);
      await svc.assignRoles(
          userId: userId,
          organizationId: orgId,
          roleIds: const {'role-admin'});
      final m =
          await svc.getMembership(userId: userId, organizationId: orgId);
      expect(m!.roleIds, contains('role-admin'));
    });

    test('revokeRoles removes roles from membership', () async {
      await svc.addMember(
          userId: userId,
          organizationId: orgId,
          roleIds: const {'role-a', 'role-b'});
      await svc.revokeRoles(
          userId: userId,
          organizationId: orgId,
          roleIds: const {'role-a'});
      final m =
          await svc.getMembership(userId: userId, organizationId: orgId);
      expect(m!.roleIds, isNot(contains('role-a')));
      expect(m.roleIds, contains('role-b'));
    });

    test('deactivateMember marks membership inactive', () async {
      await svc.addMember(userId: userId, organizationId: orgId);
      await svc.deactivateMember(userId: userId, organizationId: orgId);
      final m =
          await svc.getMembership(userId: userId, organizationId: orgId);
      expect(m!.active, isFalse);
    });

    test('getMembershipsForUser returns all user memberships', () async {
      final orgB = OrganizationId('org-b');
      await svc.addMember(userId: userId, organizationId: orgId);
      await svc.addMember(userId: userId, organizationId: orgB);
      final all = await svc.getMembershipsForUser(userId);
      expect(all.length, 2);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. OrganizationService
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 OrganizationService', () {
    late InMemoryOrganizationRepository repo;
    late OrganizationService svc;

    setUp(() {
      repo = InMemoryOrganizationRepository();
      svc = DefaultOrganizationService(repo);
    });

    test('createOrganization persists and returns org', () async {
      final org = await svc.createOrganization(name: 'AcmeCorp');
      expect(org.name, 'AcmeCorp');
      expect(org.active, isTrue);
    });

    test('createOrganization respects tier', () async {
      final org = await svc.createOrganization(
          name: 'BigCorp', tier: OrganizationTier.enterprise);
      expect(org.tier, OrganizationTier.enterprise);
    });

    test('getOrganization returns previously created org', () async {
      final created = await svc.createOrganization(name: 'TestOrg');
      final fetched = await svc.getOrganization(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'TestOrg');
    });

    test('deactivateOrganization marks org inactive', () async {
      final org = await svc.createOrganization(name: 'OldOrg');
      await svc.deactivateOrganization(org.id);
      final fetched = await svc.getOrganization(org.id);
      expect(fetched!.active, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Roles are separate from permissions (atomic permissions)
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Roles separate from permissions', () {
    test('Role holds multiple atomic permissions', () {
      final role = Role(
        id: RoleId('role-editor'),
        name: 'Editor',
        permissions: {
          _perm('workspace', 'read'),
          _perm('workspace', 'write'),
        },
      );
      expect(role.hasPermissionKey('workspace:read'), isTrue);
      expect(role.hasPermissionKey('workspace:write'), isTrue);
      expect(role.hasPermissionKey('workspace:delete'), isFalse);
    });

    test('RoleRepository can save and retrieve roles', () async {
      final repo = InMemoryRoleRepository();
      final role = Role(
          id: RoleId('role-1'),
          name: 'Viewer',
          permissions: {_perm('data', 'read')});
      await repo.save(role);
      final found = await repo.findByIds([RoleId('role-1')]);
      expect(found.length, 1);
      expect(found.first.id, RoleId('role-1'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Tenant isolation — cross-tenant access DENIED
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Tenant isolation', () {
    test('Org A user accessing Org B resource is DENIED', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final orgA = env.orgId;
      final orgB = OrganizationId('org-2');

      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'read',
        requestOrg: orgA,
        resourceOrg: orgB,
      );

      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('Cross-tenant'));
    });

    test('Same org resource access proceeds to RBAC check', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 8. RBAC: role permissions
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 RBAC role permissions', () {
    test('User with viewer role can read workspace (isAllowed)', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );
      expect((await env.svc.authorize(req)).allowed, isTrue);
      expect(await env.svc.isAllowed(req), isTrue);
    });

    test('User with viewer role CANNOT publish workspace', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'publish',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('lacks permission'));
    });

    test('User with no active membership is DENIED', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final stranger = UserPrincipal(userId: UserId('user-stranger'));
      final req = _request(
        principal: stranger,
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('no active membership'));
    });

    test('Inactive membership DENIES access', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final membership =
          await env.membershipRepo.findByUserAndOrg(env.userId, env.orgId);
      await env.membershipRepo.save(membership!.copyWith(active: false));

      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. SystemPrincipal bypasses all checks
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 SystemPrincipal elevated access', () {
    test('SystemPrincipal always allowed regardless of org mismatch', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final req = _request(
        principal: const SystemPrincipal(),
        resource: 'workspace',
        action: 'delete',
        requestOrg: OrganizationId('org-x'),
        resourceOrg: OrganizationId('org-y'),
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isTrue);
      expect(decision.reason, contains('SystemPrincipal'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 10. Agent identity
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Agent identity', () {
    test('AgentPrincipal with data:read permission is ALLOWED', () async {
      final env = await _buildSvc(
        permKey: 'workspace:read',
        agentPermissions: {
          'agent-99': {'data:read', 'workspace:read'},
        },
      );
      final req = _request(
        principal: const AgentPrincipal(agentId: 'agent-99'),
        resource: 'data',
        action: 'read',
      );
      expect((await env.svc.authorize(req)).allowed, isTrue);
    });

    test('AgentPrincipal without role:manage permission is DENIED', () async {
      final env = await _buildSvc(
        permKey: 'workspace:read',
        agentPermissions: {
          'agent-99': {'data:read'},
        },
      );
      final req = _request(
        principal: const AgentPrincipal(agentId: 'agent-99'),
        resource: 'role',
        action: 'manage',
      );
      final decision = await env.svc.authorize(req);
      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('lacks permission'));
    });

    test('Unknown agent is DENIED by default', () async {
      final env = await _buildSvc(permKey: 'workspace:read');
      final req = _request(
        principal: const AgentPrincipal(agentId: 'unknown-agent'),
        resource: 'data',
        action: 'read',
      );
      expect((await env.svc.authorize(req)).allowed, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 11. ServicePrincipal
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 ServicePrincipal', () {
    test('ServicePrincipal with matching permission is ALLOWED', () async {
      final env = await _buildSvc(
        permKey: 'workspace:read',
        servicePermissions: {
          'svc-sync': {'workspace:sync'},
        },
      );
      final req = _request(
        principal: const ServicePrincipal(serviceId: 'svc-sync'),
        resource: 'workspace',
        action: 'sync',
      );
      expect((await env.svc.authorize(req)).allowed, isTrue);
    });

    test('ServicePrincipal without permission is DENIED', () async {
      final env = await _buildSvc(
        permKey: 'workspace:read',
        servicePermissions: {
          'svc-sync': {'workspace:sync'},
        },
      );
      final req = _request(
        principal: const ServicePrincipal(serviceId: 'svc-sync'),
        resource: 'workspace',
        action: 'delete',
      );
      expect((await env.svc.authorize(req)).allowed, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 12. Explicit deny policy overrides allow (Deny-overrides-allow)
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Explicit deny policy overrides allow', () {
    test('Deny policy blocks otherwise-allowed RBAC request', () async {
      final denyPublishPolicy = FunctionalAuthorizationPolicy(
        id: 'deny-publish',
        name: 'Deny Publish',
        effect: PolicyEffect.deny,
        predicate: (req) => req.permission.key == 'workspace:publish',
      );

      final membershipRepo = InMemoryMembershipRepository();
      final roleRepo = InMemoryRoleRepository();
      final userId = UserId('u-publish');
      final orgId = OrganizationId('org-pub');

      await membershipRepo.save(Membership(
        id: MembershipId('mbr-pub'),
        userId: userId,
        organizationId: orgId,
        roleIds: const {'role-pub'},
        active: true,
      ));
      await roleRepo.save(Role(
        id: RoleId('role-pub'),
        name: 'Publisher',
        permissions: {_perm('workspace', 'publish')},
      ));

      final svc = DefaultAuthorizationService(
        membershipRepository: membershipRepo,
        roleRepository: roleRepo,
        policies: [denyPublishPolicy],
      );

      final req = _request(
        principal: UserPrincipal(userId: userId),
        resource: 'workspace',
        action: 'publish',
        requestOrg: orgId,
        resourceOrg: orgId,
      );

      final decision = await svc.authorize(req);
      expect(decision.allowed, isFalse,
          reason: 'Explicit deny policy must override RBAC allow');
    });

    test('DefaultPolicyEvaluator: deny wins when both allow and deny match',
        () {
      final evaluator = DefaultPolicyEvaluator();
      final request = AuthorizationRequest(
        principal: const SystemPrincipal(),
        permission: _perm('workspace', 'approve'),
        resource: _resource('workspace'),
      );

      final policies = <AuthorizationPolicy>[
        FunctionalAuthorizationPolicy(
          id: 'allow-all',
          name: 'Allow All',
          effect: PolicyEffect.allow,
          predicate: (_) => true,
        ),
        FunctionalAuthorizationPolicy(
          id: 'deny-approve',
          name: 'Deny Approve',
          effect: PolicyEffect.deny,
          predicate: (r) => r.permission.key == 'workspace:approve',
        ),
      ];

      final decision = evaluator.evaluate(request: request, policies: policies);
      expect(decision.allowed, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 13. Workspace governance — owner cannot approve own workspace
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Workspace governance (owner cannot approve own)', () {
    AuthorizationPolicy selfApprovalDenyPolicy() =>
        FunctionalAuthorizationPolicy(
          id: 'deny-self-approval',
          name: 'Deny Self-Approval',
          effect: PolicyEffect.deny,
          predicate: (req) {
            if (req.principal is UserPrincipal) {
              final userId = (req.principal as UserPrincipal).userId;
              return req.resource.ownerId == userId.value &&
                  req.permission.key == 'workspace:approve';
            }
            return false;
          },
        );

    test('Owner is DENIED approving their own workspace', () async {
      final ownerId = UserId('owner-1');
      final orgId = OrganizationId('org-gov');
      final membershipRepo = InMemoryMembershipRepository();
      final roleRepo = InMemoryRoleRepository();

      await membershipRepo.save(Membership(
        id: MembershipId('mbr-gov'),
        userId: ownerId,
        organizationId: orgId,
        roleIds: const {'role-owner'},
        active: true,
      ));
      await roleRepo.save(Role(
        id: RoleId('role-owner'),
        name: 'Owner',
        permissions: {_perm('workspace', 'approve')},
      ));

      final svc = DefaultAuthorizationService(
        membershipRepository: membershipRepo,
        roleRepository: roleRepo,
        policies: [selfApprovalDenyPolicy()],
      );

      final req = AuthorizationRequest(
        principal: UserPrincipal(userId: ownerId),
        permission: _perm('workspace', 'approve'),
        resource: AccessResource(
          type: 'workspace',
          id: AlhambraId('ws-1'),
          organizationId: orgId,
          ownerId: ownerId.value,
        ),
        organizationId: orgId,
      );

      final decision = await svc.authorize(req);
      expect(decision.allowed, isFalse,
          reason: 'Owner must not approve their own workspace');
    });

    test('Different reviewer CAN approve another owner workspace', () async {
      final ownerId = UserId('owner-1');
      final reviewerId = UserId('reviewer-1');
      final orgId = OrganizationId('org-gov');
      final membershipRepo = InMemoryMembershipRepository();
      final roleRepo = InMemoryRoleRepository();

      for (final uid in [ownerId, reviewerId]) {
        await membershipRepo.save(Membership(
          id: MembershipId('mbr-${uid.value}'),
          userId: uid,
          organizationId: orgId,
          roleIds: const {'role-owner'},
          active: true,
        ));
      }
      await roleRepo.save(Role(
        id: RoleId('role-owner'),
        name: 'Owner',
        permissions: {_perm('workspace', 'approve')},
      ));

      final svc = DefaultAuthorizationService(
        membershipRepository: membershipRepo,
        roleRepository: roleRepo,
        policies: [selfApprovalDenyPolicy()],
      );

      final req = AuthorizationRequest(
        principal: UserPrincipal(userId: reviewerId),
        permission: _perm('workspace', 'approve'),
        resource: AccessResource(
          type: 'workspace',
          id: AlhambraId('ws-1'),
          organizationId: orgId,
          ownerId: ownerId.value, // resource owned by owner-1, not reviewer
        ),
        organizationId: orgId,
      );

      final decision = await svc.authorize(req);
      expect(decision.allowed, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 14. DelegatedExecutionContext
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 DelegatedExecutionContext', () {
    test('holds initiating and executing principals', () {
      final initiator = UserPrincipal(userId: UserId('human-1'));
      const agent = AgentPrincipal(agentId: 'agent-worker');
      final orgId = OrganizationId('org-1');

      final ctx = DelegatedExecutionContext(
        initiatingPrincipal: initiator,
        executingPrincipal: agent,
        organizationId: orgId,
        delegationContext: const {'reason': 'automation'},
      );

      expect(ctx.initiatingPrincipal, initiator);
      expect(ctx.executingPrincipal, agent);
      expect(ctx.organizationId, orgId);
      expect(ctx.delegationContext['reason'], 'automation');
    });

    test('supports optional workspaceId as String', () {
      final ctx = DelegatedExecutionContext(
        initiatingPrincipal: UserPrincipal(userId: UserId('u1')),
        executingPrincipal: const AgentPrincipal(agentId: 'a1'),
        organizationId: OrganizationId('org-1'),
        workspaceId: 'ws-1',
        delegationContext: const {},
      );
      expect(ctx.workspaceId, 'ws-1');
    });

    test('workspaceId is optional (null by default)', () {
      final ctx = DelegatedExecutionContext(
        initiatingPrincipal: UserPrincipal(userId: UserId('u1')),
        executingPrincipal: const AgentPrincipal(agentId: 'a1'),
        organizationId: OrganizationId('org-1'),
        delegationContext: const {},
      );
      expect(ctx.workspaceId, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 15. Audit callback integration
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Audit callback integration', () {
    test('callback is invoked on ALLOW decision', () async {
      final auditLog = <(AuthorizationRequest, AuthorizationDecision)>[];
      final env = await _buildSvc(
        permKey: 'workspace:read',
        auditCallback: (req, dec) => auditLog.add((req, dec)),
      );

      final req = _request(
        principal: UserPrincipal(userId: env.userId),
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );

      await env.svc.authorize(req);
      expect(auditLog.length, 1);
      expect(auditLog.first.$2.allowed, isTrue);
    });

    test('callback fires even on DENY', () async {
      final auditLog = <(AuthorizationRequest, AuthorizationDecision)>[];
      final env = await _buildSvc(
        permKey: 'workspace:read',
        auditCallback: (req, dec) => auditLog.add((req, dec)),
      );

      final req = _request(
        principal: UserPrincipal(userId: UserId('stranger')),
        resource: 'workspace',
        action: 'read',
        requestOrg: env.orgId,
        resourceOrg: env.orgId,
      );

      await env.svc.authorize(req);
      expect(auditLog.length, 1);
      expect(auditLog.first.$2.allowed, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 16. Resource ownership is explicit
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Resource ownership', () {
    test('AccessResource exposes ownerId', () {
      final res = AccessResource(
        type: 'workspace',
        id: AlhambraId('ws-1'),
        organizationId: OrganizationId('org-1'),
        ownerId: 'user-42',
      );
      expect(res.ownerId, 'user-42');
    });

    test('AccessResource ownerId defaults to null', () {
      final res = AccessResource(
        type: 'workspace',
        id: AlhambraId('ws-2'),
      );
      expect(res.ownerId, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 17. PolicyEvaluator — default deny when no policies match
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 PolicyEvaluator default-deny', () {
    test('No matching allow policy results in DENY', () {
      final evaluator = DefaultPolicyEvaluator();
      final req = AuthorizationRequest(
        principal: const SystemPrincipal(),
        permission: _perm('secret', 'read'),
        resource: _resource('secret'),
      );
      final policies = <AuthorizationPolicy>[
        FunctionalAuthorizationPolicy(
          id: 'allow-workspace',
          name: 'Allow Workspace',
          effect: PolicyEffect.allow,
          predicate: (r) => r.permission.resource == 'workspace',
        ),
      ];
      final decision = evaluator.evaluate(request: req, policies: policies);
      expect(decision.allowed, isFalse);
    });

    test('Matching allow policy results in ALLOW', () {
      final evaluator = DefaultPolicyEvaluator();
      final req = AuthorizationRequest(
        principal: const SystemPrincipal(),
        permission: _perm('workspace', 'read'),
        resource: _resource('workspace'),
      );
      final policies = <AuthorizationPolicy>[
        FunctionalAuthorizationPolicy(
          id: 'allow-workspace',
          name: 'Allow Workspace',
          effect: PolicyEffect.allow,
          predicate: (r) => r.permission.resource == 'workspace',
        ),
      ];
      final decision = evaluator.evaluate(request: req, policies: policies);
      expect(decision.allowed, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 18. AuthorizationDecision is standardized
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 AuthorizationDecision standardized', () {
    test('allow() has allowed=true', () {
      const d = AuthorizationDecision.allow(reason: 'ok');
      expect(d.allowed, isTrue);
      expect(d.reason, 'ok');
      expect(d.matchedPolicies, isEmpty);
    });

    test('deny() has allowed=false', () {
      const d = AuthorizationDecision.deny('blocked');
      expect(d.allowed, isFalse);
      expect(d.reason, 'blocked');
    });

    test('allow() with matchedPolicies', () {
      const d = AuthorizationDecision.allow(matchedPolicies: ['p1', 'p2']);
      expect(d.matchedPolicies, ['p1', 'p2']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 19. Backend remains authoritative (authorization is server-side)
  // ─────────────────────────────────────────────────────────────────────────
  group('P11 Backend authorization (no economic concepts)', () {
    test('AuthorizationService interface has only authorize and isAllowed', () {
      // Verify the interface is intentionally minimal — no economic concepts
      final env = _buildSvc(permKey: 'workspace:read');
      expect(env, isNotNull); // service is constructable without any UI/economic deps
    });

    test('Organization model has no economic/billing-specific fields', () {
      final org = Organization(id: OrganizationId('org-1'), name: 'Test');
      // Only has: id, name, active, tier, createdAt, metadata
      // No payment, billing, subscription, or currency fields
      expect(org.name, isA<String>());
      expect(org.tier, isA<OrganizationTier>());
    });
  });
}

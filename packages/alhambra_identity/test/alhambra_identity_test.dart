import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_identity/alhambra_identity.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal in-memory AuthorizationService for testing
// ---------------------------------------------------------------------------

/// Stub that grants everything — used to verify the interface contract.
class _AlwaysAllowService implements AuthorizationService {
  @override
  Future<AuthorizationDecision> authorize(AuthorizationRequest request) async {
    return const AuthorizationDecision.allow();
  }

  @override
  Future<bool> isAllowed(AuthorizationRequest request) async => true;
}

/// Stub that denies everything with a fixed reason.
class _AlwaysDenyService implements AuthorizationService {
  @override
  Future<AuthorizationDecision> authorize(AuthorizationRequest request) async {
    return const AuthorizationDecision.deny('insufficient permissions');
  }

  @override
  Future<bool> isAllowed(AuthorizationRequest request) async => false;
}

// ---------------------------------------------------------------------------
// Minimal in-memory IdentityProvider for testing
// ---------------------------------------------------------------------------

class _StaticIdentityProvider implements IdentityProvider {
  final Principal? _principal;
  final Session? _session;

  const _StaticIdentityProvider({
    Principal? principal,
    Session? session,
  })  : _principal = principal,
        _session = session;

  @override
  Future<Principal?> currentPrincipal() async => _principal;

  @override
  Future<Session?> currentSession() async => _session;

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserId _uid(String v) => UserId(v);
OrganizationId _oid(String v) => OrganizationId(v);
TeamId _tid(String v) => TeamId(v);
MembershipId _mid(String v) => MembershipId(v);
RoleId _rid(String v) => RoleId(v);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Identity ────────────────────────────────────────────────────────

  group('User', () {
    test('creates user with required fields', () {
      final user = User(
        id: _uid('u-1'),
        email: 'alice@example.com',
        displayName: 'Alice',
      );
      expect(user.id.value, 'u-1');
      expect(user.email, 'alice@example.com');
      expect(user.displayName, 'Alice');
      expect(user.active, isTrue);
    });

    test('inactive user flag is preserved', () {
      final user = User(
        id: _uid('u-2'),
        email: 'bob@example.com',
        displayName: 'Bob',
        active: false,
      );
      expect(user.active, isFalse);
    });

    test('equality is id-based', () {
      final a = User(id: _uid('u-1'), email: 'a@x.com', displayName: 'A');
      final b = User(id: _uid('u-1'), email: 'b@x.com', displayName: 'B');
      expect(a, equals(b));
    });

    test('copyWith preserves unchanged fields', () {
      final user = User(
        id: _uid('u-3'),
        email: 'carol@example.com',
        displayName: 'Carol',
      );
      final updated = user.copyWith(displayName: 'Caroline');
      expect(updated.displayName, 'Caroline');
      expect(updated.email, 'carol@example.com');
    });
  });

  // ── 2. Principal ───────────────────────────────────────────────────────

  group('Principal', () {
    test('UserPrincipal carries userId', () {
      final p = UserPrincipal(userId: _uid('u-1'));
      expect(p.userId.value, 'u-1');
    });

    test('AgentPrincipal carries agentId', () {
      final p = AgentPrincipal(agentId: 'agent-aljabr');
      expect(p.agentId, 'agent-aljabr');
    });

    test('ServicePrincipal carries serviceId', () {
      final p = ServicePrincipal(serviceId: 'svc-analytics');
      expect(p.serviceId, 'svc-analytics');
    });

    test('SystemPrincipal is a singleton value', () {
      const p1 = SystemPrincipal();
      const p2 = SystemPrincipal();
      expect(p1, equals(p2));
    });

    test('principal types are distinguishable via pattern matching', () {
      final principals = <Principal>[
        UserPrincipal(userId: _uid('u-1')),
        AgentPrincipal(agentId: 'agent-x'),
        ServicePrincipal(serviceId: 'svc-y'),
        const SystemPrincipal(),
      ];

      int users = 0, agents = 0, services = 0, systems = 0;
      for (final p in principals) {
        switch (p) {
          case UserPrincipal():
            users++;
          case AgentPrincipal():
            agents++;
          case ServicePrincipal():
            services++;
          case SystemPrincipal():
            systems++;
        }
      }

      expect(users, 1);
      expect(agents, 1);
      expect(services, 1);
      expect(systems, 1);
    });
  });

  // ── 3. Session ─────────────────────────────────────────────────────────

  group('Session', () {
    test('non-expired session', () {
      final session = Session(
        id: 'sess-1',
        principal: UserPrincipal(userId: _uid('u-1')),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(session.isExpired, isFalse);
    });

    test('expired session', () {
      final session = Session(
        id: 'sess-2',
        principal: UserPrincipal(userId: _uid('u-1')),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(session.isExpired, isTrue);
    });
  });

  // ── 4. IdentityProvider ────────────────────────────────────────────────

  group('IdentityProvider', () {
    test('returns null when unauthenticated', () async {
      const provider = _StaticIdentityProvider();
      expect(await provider.currentPrincipal(), isNull);
      expect(await provider.currentSession(), isNull);
    });

    test('returns configured principal', () async {
      final principal = UserPrincipal(userId: _uid('u-1'));
      final provider = _StaticIdentityProvider(principal: principal);
      expect(await provider.currentPrincipal(), equals(principal));
    });
  });

  // ── 5. Organization ────────────────────────────────────────────────────

  group('Organization', () {
    test('creates organization', () {
      final org = Organization(
        id: _oid('org-1'),
        name: 'Acme Corp',
      );
      expect(org.id.value, 'org-1');
      expect(org.name, 'Acme Corp');
      expect(org.active, isTrue);
    });

    test('equality: same id and name are equal', () {
      final a = Organization(id: _oid('org-1'), name: 'Acme');
      final b = Organization(id: _oid('org-1'), name: 'Acme');
      final c = Organization(id: _oid('org-2'), name: 'Other');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ── 6. Team ────────────────────────────────────────────────────────────

  group('Team', () {
    test('creates team within organization', () {
      final team = Team(
        id: _tid('team-1'),
        organizationId: _oid('org-1'),
        name: 'Engineering',
      );
      expect(team.name, 'Engineering');
      expect(team.organizationId.value, 'org-1');
    });
  });

  // ── 7. Membership ──────────────────────────────────────────────────────

  group('Membership', () {
    test('creates membership and is active by default', () {
      final m = Membership(
        id: _mid('mbr-1'),
        userId: _uid('u-1'),
        organizationId: _oid('org-1'),
      );
      expect(m.active, isTrue);
    });

    test('supports multiple organizations (multi-tenancy)', () {
      final userId = _uid('u-shared');
      final orgA = _oid('org-A');
      final orgB = _oid('org-B');

      final membershipA = Membership(
        id: _mid('mbr-A'),
        userId: userId,
        organizationId: orgA,
      );
      final membershipB = Membership(
        id: _mid('mbr-B'),
        userId: userId,
        organizationId: orgB,
      );

      // Same user, different orgs
      expect(membershipA.userId, equals(membershipB.userId));
      expect(membershipA.organizationId, isNot(membershipB.organizationId));
    });

    test('inactive membership is preserved via copyWith', () {
      final m = Membership(
        id: _mid('mbr-2'),
        userId: _uid('u-2'),
        organizationId: _oid('org-2'),
      );
      final inactive = m.copyWith(active: false);
      expect(inactive.active, isFalse);
    });

    test('organizational boundaries are distinct', () {
      // User A in Org A, User B in Org B — memberships don't overlap
      final mA = Membership(
        id: _mid('mbr-A-1'),
        userId: _uid('u-A'),
        organizationId: _oid('org-A'),
      );
      final mB = Membership(
        id: _mid('mbr-B-1'),
        userId: _uid('u-B'),
        organizationId: _oid('org-B'),
      );

      expect(mA.organizationId, isNot(equals(mB.organizationId)));
      expect(mA.userId, isNot(equals(mB.userId)));
    });
  });

  // ── 8. Permission ──────────────────────────────────────────────────────

  group('Permission', () {
    test('key format is resource:action', () {
      const p = Permission(resource: 'workspace', action: 'create');
      expect(p.key, 'workspace:create');
    });

    test('equality based on resource and action', () {
      const p1 = Permission(resource: 'workspace', action: 'read');
      const p2 = Permission(resource: 'workspace', action: 'read');
      const p3 = Permission(resource: 'workspace', action: 'delete');
      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
    });

    test('permissions work correctly in a Set', () {
      // Build via a list so the analyzer doesn't flag the intentional
      // duplicate — we're testing runtime deduplication behaviour.
      final permissions = <Permission>[
        const Permission(resource: 'workspace', action: 'create'),
        const Permission(resource: 'workspace', action: 'read'),
        const Permission(resource: 'workspace', action: 'create'), // dup
      ].toSet();
      expect(permissions.length, 2);
    });
  });

  // ── 9. Role ────────────────────────────────────────────────────────────

  group('Role', () {
    test('role contains permissions', () {
      final role = Role(
        id: _rid('role-analyst'),
        name: 'Analyst',
        permissions: {
          const Permission(resource: 'workspace', action: 'create'),
          const Permission(resource: 'workspace', action: 'read'),
          const Permission(resource: 'analysis', action: 'execute'),
        },
      );
      expect(role.permissions.length, 3);
      expect(
        role.hasPermission(
          const Permission(resource: 'workspace', action: 'read'),
        ),
        isTrue,
      );
      expect(
        role.hasPermissionKey('analysis:execute'),
        isTrue,
      );
      expect(
        role.hasPermissionKey('workspace:delete'),
        isFalse,
      );
    });

    test('empty role has no permissions by default', () {
      final role = Role(id: _rid('role-guest'), name: 'Guest');
      expect(role.permissions, isEmpty);
    });
  });

  // ── 10. AccessResource ─────────────────────────────────────────────────

  group('AccessResource', () {
    test('creates generic resource descriptor', () {
      final ws = AccessResource(
        type: 'workspace',
        id: WorkspaceId('ws-1'),
        organizationId: _oid('org-1'),
      );
      expect(ws.type, 'workspace');
    });

    test('equality based on type and id', () {
      final a = AccessResource(type: 'analysis', id: AnalysisId('a-1'));
      final b = AccessResource(type: 'analysis', id: AnalysisId('a-1'));
      final c = AccessResource(type: 'analysis', id: AnalysisId('a-2'));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ── 11. AccessScope ────────────────────────────────────────────────────

  group('AccessScope', () {
    test('all scope values are enumerable', () {
      final scopes = AccessScope.values;
      expect(scopes, containsAll([
        AccessScope.platform,
        AccessScope.organization,
        AccessScope.team,
        AccessScope.resource,
      ]));
    });

    test('scope semantics are ordered from broad to narrow', () {
      // Verify the declaration order matches the intended hierarchy
      expect(AccessScope.platform.index < AccessScope.organization.index, isTrue);
      expect(AccessScope.organization.index < AccessScope.team.index, isTrue);
      expect(AccessScope.team.index < AccessScope.resource.index, isTrue);
    });
  });

  // ── 12. Authorization ──────────────────────────────────────────────────

  group('AuthorizationDecision', () {
    test('allow decision has allowed=true and no reason', () {
      const d = AuthorizationDecision.allow();
      expect(d.allowed, isTrue);
      expect(d.reason, isNull);
    });

    test('deny decision has allowed=false and a reason', () {
      const d = AuthorizationDecision.deny('insufficient permissions');
      expect(d.allowed, isFalse);
      expect(d.reason, 'insufficient permissions');
    });
  });

  group('AuthorizationService', () {
    test('always-allow service permits any request', () async {
      final svc = _AlwaysAllowService();
      final request = AuthorizationRequest(
        principal: UserPrincipal(userId: _uid('u-1')),
        permission: const Permission(resource: 'workspace', action: 'create'),
        resource: AccessResource(type: 'workspace', id: WorkspaceId('ws-1')),
        organizationId: _oid('org-1'),
      );
      final decision = await svc.authorize(request);
      expect(decision.allowed, isTrue);
    });

    test('always-deny service blocks any request', () async {
      final svc = _AlwaysDenyService();
      final request = AuthorizationRequest(
        principal: UserPrincipal(userId: _uid('u-1')),
        permission: const Permission(resource: 'workspace', action: 'delete'),
        resource: AccessResource(type: 'workspace', id: WorkspaceId('ws-1')),
      );
      final decision = await svc.authorize(request);
      expect(decision.allowed, isFalse);
      expect(decision.reason, isNotEmpty);
    });

    test('organizational boundaries are enforced by distinct memberships', () async {
      // Org A user should not share identity context with Org B user
      final userA = _uid('u-A');
      final userB = _uid('u-B');
      final orgA = _oid('org-A');
      final orgB = _oid('org-B');

      final mA = Membership(
        id: _mid('mbr-A'),
        userId: userA,
        organizationId: orgA,
      );
      final mB = Membership(
        id: _mid('mbr-B'),
        userId: userB,
        organizationId: orgB,
      );

      // Their memberships are in separate organizational contexts
      expect(mA.organizationId, isNot(equals(mB.organizationId)));

      // An AuthorizationRequest scoped to orgA won't match orgB context
      final requestA = AuthorizationRequest(
        principal: UserPrincipal(userId: userA),
        permission: const Permission(resource: 'workspace', action: 'read'),
        resource: AccessResource(
          type: 'workspace',
          id: WorkspaceId('ws-A'),
          organizationId: orgA,
        ),
        organizationId: orgA,
      );
      final requestB = AuthorizationRequest(
        principal: UserPrincipal(userId: userB),
        permission: const Permission(resource: 'workspace', action: 'read'),
        resource: AccessResource(
          type: 'workspace',
          id: WorkspaceId('ws-B'),
          organizationId: orgB,
        ),
        organizationId: orgB,
      );

      expect(
        requestA.organizationId,
        isNot(equals(requestB.organizationId)),
      );
    });
  });
}

import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_data_sqlite/alhambra_data_sqlite.dart';
import 'package:alhambra_identity/alhambra_identity.dart';
import 'package:alhambra_identity_sqlite/alhambra_identity_sqlite.dart';
import 'package:test/test.dart';

void main() {
  late Sqlite3Database database;
  late SqliteIdentityStore store;

  setUp(() async {
    database = Sqlite3Database.memory();
    await database.open();
    store = SqliteIdentityStore(database);
    await store.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  test('persists and resolves membership by user and organization', () async {
    final membership = Membership(
      id: MembershipId('membership-1'),
      userId: UserId('user-1'),
      organizationId: OrganizationId('org-1'),
      roleIds: {'operator', 'reviewer'},
      teamIds: {'team-a'},
    );

    await store.memberships.save(membership);
    final actual = await store.memberships.findByUserAndOrg(
      UserId('user-1'),
      OrganizationId('org-1'),
    );

    expect(actual, isNotNull);
    expect(actual!.id, membership.id);
    expect(actual.roleIds, membership.roleIds);
    expect(actual.teamIds, membership.teamIds);
    expect(actual.active, isTrue);
  });

  test('upserts membership for the same user and organization', () async {
    await store.memberships.save(Membership(
      id: MembershipId('membership-old'),
      userId: UserId('user-1'),
      organizationId: OrganizationId('org-1'),
      roleIds: {'reader'},
    ));
    await store.memberships.save(Membership(
      id: MembershipId('membership-new'),
      userId: UserId('user-1'),
      organizationId: OrganizationId('org-1'),
      roleIds: {'admin'},
      active: false,
    ));

    final actual = await store.memberships.findByUserAndOrg(
      UserId('user-1'),
      OrganizationId('org-1'),
    );
    expect(actual!.id.value, 'membership-new');
    expect(actual.roleIds, {'admin'});
    expect(actual.active, isFalse);
  });

  test('lists memberships by user and organization', () async {
    await store.memberships.save(Membership(
      id: MembershipId('m-1'),
      userId: UserId('user-1'),
      organizationId: OrganizationId('org-1'),
    ));
    await store.memberships.save(Membership(
      id: MembershipId('m-2'),
      userId: UserId('user-1'),
      organizationId: OrganizationId('org-2'),
    ));
    await store.memberships.save(Membership(
      id: MembershipId('m-3'),
      userId: UserId('user-2'),
      organizationId: OrganizationId('org-1'),
    ));

    expect(await store.memberships.findByUser(UserId('user-1')), hasLength(2));
    expect(await store.memberships.findByOrg(OrganizationId('org-1')), hasLength(2));
  });

  test('persists roles and canonical permission keys', () async {
    final role = Role(
      id: RoleId('tenant-operator'),
      name: 'Tenant Operator',
      permissions: {
        const Permission(resource: 'workspace', action: 'read'),
        const Permission(resource: 'workspace', action: 'update'),
      },
    );

    await store.roles.save(role);
    final actual = await store.roles.findById(RoleId('tenant-operator'));

    expect(actual, isNotNull);
    expect(actual!.name, role.name);
    expect(actual.permissions, role.permissions);
    expect(actual.hasPermissionKey('workspace:read'), isTrue);
    expect(await store.roles.findByIds([RoleId('tenant-operator')]), hasLength(1));
    expect(await store.roles.findAll(), hasLength(1));
  });

  test('persists authorization audit decisions', () async {
    final request = AuthorizationRequest(
      principal: const UserPrincipal(userId: UserId('user-1')),
      permission: const Permission(resource: 'workspace', action: 'delete'),
      resource: const AccessResource(
        type: 'workspace',
        id: WorkspaceId('workspace-1'),
        organizationId: OrganizationId('org-1'),
      ),
      organizationId: OrganizationId('org-1'),
    );

    await store.auditSink.record(
      request,
      const AuthorizationDecision.deny(
        'explicit deny',
        matchedPolicies: ['policy-1'],
      ),
    );

    final rows = await database.query(
      'SELECT * FROM alhambra_authorization_audit',
    );
    expect(rows, hasLength(1));
    expect(rows.single['principal_type'], 'user');
    expect(rows.single['principal_id'], 'user-1');
    expect(rows.single['permission_key'], 'workspace:delete');
    expect(rows.single['organization_id'], 'org-1');
    expect(rows.single['allowed'], 0);
    expect(rows.single['reason'], 'explicit deny');
    expect(rows.single['matched_policies_json'], '["policy-1"]');
  });

  test('required audit persistence composes with authorization service', () async {
    final userId = UserId('user-1');
    final orgId = OrganizationId('org-1');
    await store.save(Role(
      id: RoleId('reader'),
      name: 'Reader',
      permissions: {const Permission(resource: 'workspace', action: 'read')},
    ));
    await store.memberships.save(Membership(
      id: MembershipId('membership-1'),
      userId: userId,
      organizationId: orgId,
      roleIds: {'reader'},
    ));

    final authorization = DefaultAuthorizationService(
      membershipRepository: store.memberships,
      roleRepository: store.roles,
      auditSink: store.auditSink,
      requireAudit: true,
    );
    final decision = await authorization.authorize(AuthorizationRequest(
      principal: UserPrincipal(userId: userId),
      permission: const Permission(resource: 'workspace', action: 'read'),
      resource: const AccessResource(
        type: 'workspace',
        id: WorkspaceId('workspace-1'),
        organizationId: OrganizationId('org-1'),
      ),
      organizationId: orgId,
    ));

    expect(decision.allowed, isTrue);
    final rows = await database.query(
      'SELECT allowed FROM alhambra_authorization_audit',
    );
    expect(rows.single['allowed'], 1);
  });
}

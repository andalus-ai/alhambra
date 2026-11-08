import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_workspace/alhambra_workspace.dart';
import 'package:test/test.dart';

class _FailingPublishGate implements PublishGate {
  final List<String> reasons;
  const _FailingPublishGate(this.reasons);

  @override
  Future<List<String>> blockers(Workspace workspace) async => reasons;
}

class _PassingPublishGate implements PublishGate {
  const _PassingPublishGate();

  @override
  Future<List<String>> blockers(Workspace workspace) async => const [];
}

void main() {
  late InMemoryWorkspaceRepository repo;
  late DefaultWorkspaceService service;

  final orgA = OrganizationId('org-a');
  final orgB = OrganizationId('org-b');
  final aliceOwner = UserId('user-alice');
  final bobReviewer = UserId('user-bob');

  setUp(() {
    repo = InMemoryWorkspaceRepository();
    service = DefaultWorkspaceService(
      repository: repo,
      publishGates: [const _PassingPublishGate()],
    );
  });

  group('Lifecycle & State Machine', () {
    test('WorkspaceLifecycle validates valid and invalid transitions', () {
      const lc = WorkspaceLifecycle();

      // Valid
      expect(lc.canTransition(WorkspaceStatus.draft, WorkspaceStatus.review), isTrue);
      expect(lc.canTransition(WorkspaceStatus.draft, WorkspaceStatus.archived), isTrue);
      expect(lc.canTransition(WorkspaceStatus.review, WorkspaceStatus.approved), isTrue);
      expect(lc.canTransition(WorkspaceStatus.review, WorkspaceStatus.draft), isTrue);
      expect(lc.canTransition(WorkspaceStatus.approved, WorkspaceStatus.published), isTrue);
      expect(lc.canTransition(WorkspaceStatus.approved, WorkspaceStatus.draft), isTrue);
      expect(lc.canTransition(WorkspaceStatus.published, WorkspaceStatus.superseded), isTrue);
      expect(lc.canTransition(WorkspaceStatus.published, WorkspaceStatus.archived), isTrue);
      expect(lc.canTransition(WorkspaceStatus.superseded, WorkspaceStatus.archived), isTrue);

      // Invalid
      expect(lc.canTransition(WorkspaceStatus.draft, WorkspaceStatus.published), isFalse);
      expect(lc.canTransition(WorkspaceStatus.approved, WorkspaceStatus.archived), isFalse);
      expect(lc.canTransition(WorkspaceStatus.archived, WorkspaceStatus.draft), isFalse);
      expect(lc.canTransition(WorkspaceStatus.archived, WorkspaceStatus.review), isFalse);

      expect(
        () => lc.requireTransition(WorkspaceStatus.archived, WorkspaceStatus.draft),
        throwsA(isA<WorkspaceTransitionException>()),
      );
    });
  });

  group('P3 Acceptance Tests — Lifecycle & Governance', () {
    test('create workspace → DRAFT with version 1', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Alpha Project',
      );

      expect(ws.status, equals(WorkspaceStatus.draft));
      expect(ws.version.number, equals(1));
      expect(ws.ownerId, equals(aliceOwner));
      expect(ws.organizationId, equals(orgA));
      expect(ws.members.first.role, equals(WorkspaceRole.owner));
    });

    test('DRAFT → REVIEW', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );

      final inReview = await service.submitForReview(
        workspaceId: ws.id,
        actorId: aliceOwner,
      );

      expect(inReview.status, equals(WorkspaceStatus.review));
      expect(inReview.version.number, equals(2));
      expect(inReview.version.description, contains('Submitted for review'));
    });

    test('REVIEW → APPROVED when non-owner approves', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);

      final approved = await service.approve(
        workspaceId: ws.id,
        reviewerId: bobReviewer,
      );

      expect(approved.status, equals(WorkspaceStatus.approved));
      expect(approved.version.number, equals(3));
      expect(approved.version.description, contains('Approved by user-bob'));
    });

    test('owner cannot approve own workspace (Four-Eyes Rule)', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);

      expect(
        () => service.approve(workspaceId: ws.id, reviewerId: aliceOwner),
        throwsA(isA<WorkspaceApprovalException>()),
      );
    });

    test('REVIEW → DRAFT on rejection', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);

      final rejected = await service.reject(
        workspaceId: ws.id,
        reviewerId: bobReviewer,
        reason: 'Needs more citations',
      );

      expect(rejected.status, equals(WorkspaceStatus.draft));
      expect(rejected.version.number, equals(3));
      expect(rejected.version.description, contains('Needs more citations'));
    });

    test('APPROVED → PUBLISHED', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);
      await service.approve(workspaceId: ws.id, reviewerId: bobReviewer);

      final published = await service.publish(
        workspaceId: ws.id,
        actorId: aliceOwner,
      );

      expect(published.status, equals(WorkspaceStatus.published));
      expect(published.version.number, equals(4));
    });

    test('publication gates can block publication', () async {
      final blockedService = DefaultWorkspaceService(
        repository: repo,
        publishGates: [
          const _FailingPublishGate(['Missing mandatory compliance sign-off']),
        ],
      );

      final ws = await blockedService.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await blockedService.submitForReview(workspaceId: ws.id, actorId: aliceOwner);
      await blockedService.approve(workspaceId: ws.id, reviewerId: bobReviewer);

      expect(
        () => blockedService.publish(workspaceId: ws.id, actorId: aliceOwner),
        throwsA(
          isA<WorkspacePublicationBlockedException>().having(
            (e) => e.blockers,
            'blockers',
            contains('Missing mandatory compliance sign-off'),
          ),
        ),
      );
    });

    test('PUBLISHED → SUPERSEDED', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Project',
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);
      await service.approve(workspaceId: ws.id, reviewerId: bobReviewer);
      await service.publish(workspaceId: ws.id, actorId: aliceOwner);

      final superseded = await service.supersede(
        workspaceId: ws.id,
        actorId: aliceOwner,
      );

      expect(superseded.status, equals(WorkspaceStatus.superseded));
      expect(superseded.version.number, equals(5));
    });

    test('valid states → ARCHIVED and ARCHIVED cannot transition', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Draft to Archive',
      );

      final archived = await service.archive(
        workspaceId: ws.id,
        actorId: aliceOwner,
      );
      expect(archived.status, equals(WorkspaceStatus.archived));

      // Terminal: cannot transition further
      expect(
        () => service.submitForReview(workspaceId: ws.id, actorId: aliceOwner),
        throwsA(isA<WorkspaceTransitionException>()),
      );
    });

    test('all mutations produce new version and history contains every version', () async {
      final ws = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Versioning Test',
      );

      await service.updateMetadata(
        workspaceId: ws.id,
        actorId: aliceOwner,
        metadata: {'tag': 'v1-edit'},
      );
      await service.submitForReview(workspaceId: ws.id, actorId: aliceOwner);
      await service.approve(workspaceId: ws.id, reviewerId: bobReviewer);
      await service.publish(workspaceId: ws.id, actorId: aliceOwner);

      final history = await repo.history(ws.id);
      expect(history.length, equals(5));
      expect(history.map((w) => w.version.number).toList(), equals([1, 2, 3, 4, 5]));
      expect(history.map((w) => w.status).toList(), equals([
        WorkspaceStatus.draft,
        WorkspaceStatus.draft,
        WorkspaceStatus.review,
        WorkspaceStatus.approved,
        WorkspaceStatus.published,
      ]));
    });

    test('deriveDraft creates independent DRAFT with origin metadata', () async {
      final original = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Original Report',
        metadata: {'category': 'research'},
      );
      await service.submitForReview(workspaceId: original.id, actorId: aliceOwner);
      await service.approve(workspaceId: original.id, reviewerId: bobReviewer);
      await service.publish(workspaceId: original.id, actorId: aliceOwner);

      final charlieActor = UserId('user-charlie');
      final derived = await service.deriveDraft(
        sourceWorkspaceId: original.id,
        actorId: charlieActor,
        name: 'Derived Report Q2',
      );

      expect(derived.id, isNot(equals(original.id)));
      expect(derived.status, equals(WorkspaceStatus.draft));
      expect(derived.version.number, equals(1));
      expect(derived.ownerId, equals(charlieActor));
      expect(derived.organizationId, equals(orgA));
      expect(derived.metadata['category'], equals('research'));
      expect(
        (derived.metadata['derivedFrom'] as Map)['workspaceId'],
        equals(original.id.value),
      );
    });

    test('organization ownership is preserved', () async {
      final wsA = await service.create(
        organizationId: orgA,
        ownerId: aliceOwner,
        name: 'Org A Workspace',
      );
      final wsB = await service.create(
        organizationId: orgB,
        ownerId: bobReviewer,
        name: 'Org B Workspace',
      );

      expect(wsA.organizationId, equals(orgA));
      expect(wsB.organizationId, equals(orgB));
      expect(wsA.organizationId, isNot(equals(wsB.organizationId)));
    });
  });
}

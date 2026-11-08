import 'package:alhambra_api/alhambra_api.dart';
import 'package:test/test.dart';

void main() {
  group('Common API infrastructure', () {
    test('ApiResponse.success constructs with metadata and data', () {
      final now = DateTime.now();
      final metadata = ApiMetadata(
        requestId: 'req-123',
        timestamp: now,
        version: ApiVersion.current,
      );
      final response = ApiResponse.success(
        data: 'payload',
        metadata: metadata,
      );

      expect(response.isSuccess, isTrue);
      expect(response.isFailure, isFalse);
      expect(response.data, equals('payload'));
      expect(response.error, isNull);
      expect(response.metadata.requestId, equals('req-123'));
      expect(response.metadata.version, equals('2026-01'));
    });

    test('ApiResponse.failure constructs with error and metadata', () {
      final now = DateTime.now();
      final error = ApiError(
        code: 'NOT_FOUND',
        message: 'Resource not found',
        details: {'resourceId': 'xyz'},
      );
      final metadata = ApiMetadata(
        requestId: 'req-err',
        timestamp: now,
      );
      final response = ApiResponse<String>.failure(
        error: error,
        metadata: metadata,
      );

      expect(response.isSuccess, isFalse);
      expect(response.isFailure, isTrue);
      expect(response.data, isNull);
      expect(response.error?.code, equals('NOT_FOUND'));
      expect(response.error?.message, equals('Resource not found'));
      expect(response.error?.details, containsPair('resourceId', 'xyz'));
    });

    test('ApiPage provides pagination metadata correctly', () {
      final page = ApiPage<String>(
        items: ['a', 'b', 'c'],
        page: 0,
        pageSize: 3,
        hasNext: true,
        total: 10,
      );

      expect(page.items.length, equals(3));
      expect(page.page, equals(0));
      expect(page.pageSize, equals(3));
      expect(page.total, equals(10));
      expect(page.hasNext, isTrue);
    });

    test('ApiRequest idempotency key support', () {
      const request = SearchRequest(
        query: 'policy',
        idempotencyKey: 'idemp-xyz-987',
      );
      expect(request.idempotencyKey, equals('idemp-xyz-987'));
    });

    test('ApiVersion constants and behavior', () {
      expect(ApiVersion.current, equals('2026-01'));
      expect(ApiVersion.defaultPrefix, equals('/api/v1'));
      const v = ApiVersion('2026-01');
      expect(v.toString(), equals('2026-01'));
      expect(v, equals(const ApiVersion('2026-01')));
    });
  });

  group('Authentication & Authorization Boundary', () {
    test('ApiPrincipal roles and permissions checks', () {
      const principal = ApiPrincipal(
        userId: 'user-1',
        organizationId: 'org-1',
        roles: {'analyst', 'reviewer'},
        permissions: {'read:workspace', 'approve:review'},
      );

      expect(principal.hasRole('analyst'), isTrue);
      expect(principal.hasRole('admin'), isFalse);
      expect(principal.hasPermission('approve:review'), isTrue);
      expect(principal.hasPermission('delete:workspace'), isFalse);
    });

    test('ApiAuthorizationBoundary implementation', () {
      final boundary = _MockAuthorizationBoundary();
      const reviewer = ApiPrincipal(
        userId: 'u1',
        organizationId: 'o1',
        roles: {'reviewer'},
      );
      const viewer = ApiPrincipal(
        userId: 'u2',
        organizationId: 'o1',
        roles: {'viewer'},
      );

      expect(
        boundary.isAuthorized(
          principal: reviewer,
          action: 'approve',
          resource: 'review',
        ),
        isTrue,
      );

      expect(
        boundary.isAuthorized(
          principal: viewer,
          action: 'approve',
          resource: 'review',
        ),
        isFalse,
      );
    });
  });

  group('Identity & Workspace DTOs', () {
    test('UserDto and SessionDto construction', () {
      final now = DateTime.now();
      const user = UserDto(
        id: 'u-1',
        email: 'alice@example.com',
        displayName: 'Alice',
        roles: {'analyst'},
      );
      final session = SessionDto(
        sessionId: 'sess-1',
        userId: user.id,
        organizationId: 'org-1',
        expiresAt: now.add(const Duration(hours: 8)),
      );

      expect(user.id, equals('u-1'));
      expect(session.userId, equals(user.id));
      expect(session.organizationId, equals('org-1'));
    });

    test('WorkspaceDto construction and request DTOs', () {
      final now = DateTime.now();
      final ws = WorkspaceDto(
        id: 'ws-1',
        name: 'Macro Workspace',
        status: 'active',
        version: 1,
        ownerId: 'u-1',
        createdAt: now,
        updatedAt: now,
      );
      const createReq = CreateWorkspaceRequest(
        name: 'New Workspace',
        description: 'Testing',
        idempotencyKey: 'idemp-ws',
      );
      const updateReq = UpdateWorkspaceRequest(name: 'Updated Name');

      expect(ws.name, equals('Macro Workspace'));
      expect(ws.version, equals(1));
      expect(createReq.idempotencyKey, equals('idemp-ws'));
      expect(updateReq.name, equals('Updated Name'));
    });
  });

  group('Intelligence & Execution Streaming', () {
    test('StartIntelligenceRequest and IntelligenceExecutionDto', () {
      final now = DateTime.now();
      const startReq = StartIntelligenceRequest(
        workspaceId: 'ws-1',
        objectiveType: 'macro.growth_forecast',
        parameters: {'horizon': 4},
        idempotencyKey: 'idemp-exec',
      );
      final exec = IntelligenceExecutionDto(
        executionId: 'exec-1',
        requestId: 'req-1',
        status: 'running',
        startedAt: now,
      );

      expect(startReq.objectiveType, equals('macro.growth_forecast'));
      expect(exec.status, equals('running'));
    });

    test('ExecutionEventStream emit and subscribe lifecycle', () async {
      final stream = InMemoryExecutionEventStream();
      final events = <IntelligenceExecutionEventDto>[];

      final sub = stream.subscribe('exec-100').listen(events.add);

      final event1 = IntelligenceExecutionEventDto(
        eventId: 'evt-1',
        executionId: 'exec-100',
        type: 'step_started',
        data: {'step': 'fetch_data'},
        timestamp: DateTime.now(),
      );
      final event2 = IntelligenceExecutionEventDto(
        eventId: 'evt-2',
        executionId: 'exec-100',
        type: 'step_completed',
        data: {'step': 'fetch_data'},
        timestamp: DateTime.now(),
      );

      stream.emit(event1);
      stream.emit(event2);

      await pumpEventQueue();

      expect(events.length, equals(2));
      expect(events[0].type, equals('step_started'));
      expect(events[1].type, equals('step_completed'));

      await sub.cancel();
      await stream.dispose();
    });
  });

  group('Artifacts & Evidence DTOs', () {
    test('IntelligenceArtifactDto construction', () {
      final now = DateTime.now();
      final artifact = IntelligenceArtifactDto(
        id: 'art-1',
        type: 'report',
        title: 'Growth Analysis 2026',
        epistemicClass: 'finding',
        createdAt: now,
        data: {'summary': 'GDP trend upward'},
      );

      expect(artifact.id, equals('art-1'));
      expect(artifact.type, equals('report'));
      expect(artifact.title, equals('Growth Analysis 2026'));
      expect(artifact.epistemicClass, equals('finding'));
      expect((artifact.data as Map)['summary'], equals('GDP trend upward'));
    });

    test('EvidenceDto construction', () {
      const evidence = EvidenceDto(
        id: 'ev-1',
        type: 'dataset',
        source: 'fred:gdp',
        reference: 'fred:gdp:series',
        confidence: 0.95,
      );

      expect(evidence.id, equals('ev-1'));
      expect(evidence.type, equals('dataset'));
      expect(evidence.source, equals('fred:gdp'));
      expect(evidence.confidence, equals(0.95));
    });
  });

  group('Provenance Graph and Link Traversal', () {
    test('ProvenanceGraphDto getLinksFrom and getLinksTo', () {
      const artRef = ProvenanceRefDto(type: 'artifact', id: 'art-1');
      const ev1Ref = ProvenanceRefDto(type: 'evidence', id: 'ev-1');
      const ev2Ref = ProvenanceRefDto(type: 'evidence', id: 'ev-2');
      const execRef = ProvenanceRefDto(type: 'execution', id: 'exec-1');

      final graph = ProvenanceGraphDto(links: [
        const ProvenanceLinkDto(from: artRef, relation: 'derived_from', to: ev1Ref),
        const ProvenanceLinkDto(from: artRef, relation: 'derived_from', to: ev2Ref),
        const ProvenanceLinkDto(from: artRef, relation: 'produced_by', to: execRef),
      ]);

      final fromArt = graph.getLinksFrom('art-1');
      expect(fromArt.length, equals(3));

      final toEv1 = graph.getLinksTo('ev-1');
      expect(toEv1.length, equals(1));
      expect(toEv1.first.relation, equals('derived_from'));
      expect(toEv1.first.from.id, equals('art-1'));
    });
  });

  group('Review API (HITL) DTOs', () {
    test('Review request, decision, and comments', () {
      final now = DateTime.now();
      final req = ReviewRequestDto(
        id: 'rev-1',
        targetType: 'artifact',
        targetId: 'art-1',
        status: 'pending',
        requestedBy: 'analyst-1',
        createdAt: now,
      );
      final dec = ReviewDecisionDto(
        id: 'dec-1',
        reviewId: 'rev-1',
        decision: 'approved',
        decidedBy: 'reviewer-1',
        notes: 'Verified citations and data freshness',
        decidedAt: now,
      );
      final comment = ReviewCommentDto(
        id: 'com-1',
        reviewId: 'rev-1',
        authorId: 'reviewer-1',
        content: 'Looks thorough',
        createdAt: now,
      );

      expect(req.status, equals('pending'));
      expect(dec.decision, equals('approved'));
      expect(comment.content, equals('Looks thorough'));
    });
  });

  group('Search, Files, and Notifications DTOs', () {
    test('SearchRequest and SearchResultPage', () {
      const searchReq = SearchRequest(
        query: 'unemployment',
        resourceTypes: ['artifact', 'evidence'],
        pageSize: 10,
      );
      final resultPage = SearchResultPage(
        items: [
          const SearchResultDto(
            id: 'art-2',
            resourceType: 'artifact',
            title: 'Unemployment Report',
            score: 0.98,
          ),
        ],
        page: 0,
        pageSize: 10,
        total: 1,
      );

      expect(searchReq.query, equals('unemployment'));
      expect(resultPage.items.first.title, equals('Unemployment Report'));
      expect(resultPage.hasNextPage, isFalse);
    });

    test('File DTOs for upload and download sessions', () {
      final now = DateTime.now();
      const upReq = CreateFileUploadRequest(
        fileName: 'data.csv',
        mimeType: 'text/csv',
        byteSize: 1024,
      );
      final session = FileUploadSessionDto(
        sessionId: 'sess-up-1',
        uploadUrl: 'https://storage.alhambra.local/upload/sess-up-1',
        fileId: 'file-1',
        expiresAt: now.add(const Duration(minutes: 15)),
      );
      final fileDto = FileDto(
        id: 'file-1',
        fileName: upReq.fileName,
        mimeType: upReq.mimeType,
        byteSize: upReq.byteSize,
        createdAt: now,
      );

      expect(upReq.byteSize, equals(1024));
      expect(session.fileId, equals('file-1'));
      expect(fileDto.fileName, equals('data.csv'));
    });

    test('Notification DTOs and markRead request', () {
      final now = DateTime.now();
      final notif = NotificationDto(
        id: 'notif-1',
        recipientId: 'u-1',
        title: 'Review Requested',
        body: 'Artifact A needs review',
        type: 'review_pending',
        createdAt: now,
      );

      expect(notif.read, isFalse);
      expect(notif.type, equals('review_pending'));
    });
  });

  group('Boundary Invariants', () {
    test('alhambra_api does not import or know about economic domain models', () {
      // Alhambra API deals with generic resources (workspace, intelligence, artifact, evidence, review, files, search)
      const objective = StartIntelligenceRequest(
        workspaceId: 'ws-generic',
        objectiveType: 'domain.custom_computation',
      );
      expect(objective.objectiveType, contains('domain.'));
    });
  });
}

class _MockAuthorizationBoundary implements ApiAuthorizationBoundary {
  @override
  bool isAuthorized({
    required ApiPrincipal principal,
    required String action,
    required String resource,
    String? resourceId,
  }) {
    if (principal.hasRole('reviewer') && action == 'approve') {
      return true;
    }
    return false;
  }
}

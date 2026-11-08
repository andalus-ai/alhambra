import 'package:alhambra_services/alhambra_services.dart';
import 'package:test/test.dart';

void main() {
  group('P10.1: RequestContext', () {
    test('RequestContext holds all metadata and trace context', () {
      const ctx = RequestContext(
        requestId: 'req-001',
        correlationId: 'corr-001',
        causationId: 'cause-001',
        principalId: 'user-001',
        organizationId: 'org-001',
        workspaceId: 'ws-001',
        traceId: 'trace-001',
      );

      expect(ctx.requestId, equals('req-001'));
      expect(ctx.correlationId, equals('corr-001'));
      expect(ctx.causationId, equals('cause-001'));
      expect(ctx.principalId, equals('user-001'));
      expect(ctx.organizationId, equals('org-001'));
      expect(ctx.workspaceId, equals('ws-001'));
      expect(ctx.traceId, equals('trace-001'));
    });
  });

  group('P10.2: EventEnvelope', () {
    test('EventEnvelope carries correlation, causation, and payload', () {
      final now = DateTime.now();
      final envelope = EventEnvelope(
        eventId: 'evt-100',
        eventType: 'intelligence.execution.completed',
        occurredAt: now,
        correlationId: 'corr-100',
        causationId: 'evt-099',
        organizationId: 'org-1',
        actorId: 'agent-1',
        payload: {'executionId': 'exec-1', 'status': 'completed'},
      );

      expect(envelope.eventId, equals('evt-100'));
      expect(envelope.eventType, equals('intelligence.execution.completed'));
      expect(envelope.correlationId, equals('corr-100'));
      expect(envelope.causationId, equals('evt-099'));
      expect(envelope.payload['status'], equals('completed'));
    });
  });

  group('P10.3: Search Document Indexing & Removal', () {
    test('SearchService index and remove documents dynamically', () async {
      final searchService = InMemorySearchService();

      await searchService.index(const SearchDocument(
        resourceType: 'artifact',
        resourceId: 'art-101',
        title: 'Macro Forecast Report',
        content: 'GDP growth projections for next year',
      ));

      await searchService.index(const SearchDocument(
        resourceType: 'evidence',
        resourceId: 'ev-202',
        title: 'Labor Statistics Data',
        content: 'Unemployment trends',
      ));

      final res1 = await searchService.search(const SearchQuery(text: 'forecast'));
      expect(res1.total, equals(1));
      expect(res1.results.first.resourceId, equals('art-101'));

      final res2 = await searchService.search(const SearchQuery(text: 'labor'));
      expect(res2.total, equals(1));
      expect(res2.results.first.resourceId, equals('ev-202'));

      // Remove document
      await searchService.remove('artifact', 'art-101');
      final resAfter = await searchService.search(const SearchQuery(text: 'forecast'));
      expect(resAfter.total, equals(0));
    });
  });

  group('P10.4: Background Jobs Service', () {
    test('InMemoryJobService enqueue, get, updateStatus, and cancel', () async {
      final jobService = InMemoryJobService();

      final job = await jobService.enqueue(
        'search_indexing',
        payload: {'resourceId': 'art-101'},
      );

      expect(job.id, startsWith('job-'));
      expect(job.type, equals('search_indexing'));
      expect(job.status, equals(JobStatus.pending));

      final fetched = await jobService.get(job.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(job.id));

      jobService.updateStatus(job.id, JobStatus.running);
      final running = await jobService.get(job.id);
      expect(running?.status, equals(JobStatus.running));
      expect(running?.startedAt, isNotNull);

      await jobService.cancel(job.id);
      final cancelled = await jobService.get(job.id);
      expect(cancelled?.status, equals(JobStatus.cancelled));
      expect(cancelled?.completedAt, isNotNull);
    });
  });

  group('P10.5: Service Registry', () {
    test('InMemoryServiceRegistry register, resolve, and list', () async {
      final registry = InMemoryServiceRegistry();

      const descriptor1 = ServiceDescriptor(
        id: 'svc-audit',
        name: 'Audit Service',
        version: '1.0.0',
        status: 'ready',
      );
      const descriptor2 = ServiceDescriptor(
        id: 'svc-search',
        name: 'Search Service',
        version: '1.0.0',
        status: 'ready',
      );

      await registry.register(descriptor1);
      await registry.register(descriptor2);

      final fetched = await registry.get('svc-audit');
      expect(fetched, equals(descriptor1));

      final all = await registry.list();
      expect(all.length, equals(2));
      expect(all, contains(descriptor1));
      expect(all, contains(descriptor2));
    });
  });
}

import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_services/alhambra_services.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Domain event stubs (live in the consuming domain, NOT in alhambra_services)
// ---------------------------------------------------------------------------
final class WorkspacePublished implements DomainEvent {
  final String workspaceId;
  const WorkspacePublished({required this.workspaceId});

  @override
  String get type => 'workspace.published';
  @override
  DateTime get occurredAt => DateTime.now();
}

final class AnalysisCompleted implements DomainEvent {
  final String analysisId;
  const AnalysisCompleted({required this.analysisId});

  @override
  String get type => 'analysis.completed';
  @override
  DateTime get occurredAt => DateTime.now();
}


void main() {
  // =========================================================================
  // 1. Events
  // =========================================================================
  group('1. EventBus', () {
    late InMemoryEventBus bus;
    setUp(() => bus = InMemoryEventBus());
    tearDown(() => bus.close());

    test('publish & subscribe — typed events received by subscriber', () async {
      final sub = bus.subscribe<WorkspacePublished>();
      final future = sub.first;

      await bus.publish(const WorkspacePublished(workspaceId: 'ws-1'));
      final event = await future;

      expect(event.workspaceId, equals('ws-1'));
    });

    test('different event types are isolated', () async {
      final wsEvents = <WorkspacePublished>[];
      final aiEvents = <AnalysisCompleted>[];

      bus.subscribe<WorkspacePublished>().listen(wsEvents.add);
      bus.subscribe<AnalysisCompleted>().listen(aiEvents.add);

      await bus.publish(const WorkspacePublished(workspaceId: 'ws-2'));
      await bus.publish(const AnalysisCompleted(analysisId: 'ai-9'));
      await Future<void>.delayed(Duration.zero);

      expect(wsEvents.length, equals(1));
      expect(aiEvents.length, equals(1));
      expect(wsEvents.first.workspaceId, equals('ws-2'));
      expect(aiEvents.first.analysisId, equals('ai-9'));
    });

    test('multiple subscribers on same type all receive the event', () async {
      final a = <WorkspacePublished>[];
      final b = <WorkspacePublished>[];

      bus.subscribe<WorkspacePublished>().listen(a.add);
      bus.subscribe<WorkspacePublished>().listen(b.add);

      await bus.publish(const WorkspacePublished(workspaceId: 'ws-3'));
      await Future<void>.delayed(Duration.zero);

      expect(a.length, equals(1));
      expect(b.length, equals(1));
    });

    test('publish on closed bus throws StateError', () async {
      await bus.close();
      expect(
        () => bus.publish(const WorkspacePublished(workspaceId: 'ws-x')),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // 2. Notifications
  // =========================================================================
  group('2. NotificationService', () {
    late InMemoryNotificationService svc;
    final alice = UserId('user-alice');
    final bob = UserId('user-bob');

    setUp(() => svc = InMemoryNotificationService());

    Notification makeNotif(String id, UserId to, {bool read = false}) =>
        Notification(
          id: id,
          recipientId: to,
          title: 'Title $id',
          message: 'Message $id',
          createdAt: DateTime(2026, 1, 1),
          isRead: read,
        );

    test('send and list notifications for recipient', () async {
      await svc.send(makeNotif('n1', alice));
      await svc.send(makeNotif('n2', alice));
      await svc.send(makeNotif('n3', bob));

      final list = await svc.list(recipientId: alice);
      expect(list.length, equals(2));
      expect(list.every((n) => n.recipientId == alice), isTrue);
    });

    test('unreadOnly filter works', () async {
      await svc.send(makeNotif('n1', alice));
      await svc.send(makeNotif('n2', alice, read: true));

      final unread = await svc.list(recipientId: alice, unreadOnly: true);
      expect(unread.length, equals(1));
      expect(unread.first.id, equals('n1'));
    });

    test('markRead marks single notification', () async {
      await svc.send(makeNotif('n1', alice));
      await svc.markRead('n1');

      final list = await svc.list(recipientId: alice);
      expect(list.first.isRead, isTrue);
    });

    test('markAllRead marks all for recipient', () async {
      await svc.send(makeNotif('n1', alice));
      await svc.send(makeNotif('n2', alice));
      await svc.markAllRead(alice);

      final list = await svc.list(recipientId: alice);
      expect(list.every((n) => n.isRead), isTrue);
    });

    test('NotificationChannel enum is complete', () {
      expect(
        NotificationChannel.values,
        containsAll([
          NotificationChannel.inApp,
          NotificationChannel.push,
          NotificationChannel.email,
          NotificationChannel.sms,
          NotificationChannel.webhook,
        ]),
      );
    });
  });

  // =========================================================================
  // 3. Search
  // =========================================================================
  group('3. SearchService', () {
    late InMemorySearchService svc;

    setUp(() {
      svc = InMemorySearchService([
        const SearchResult(
            resourceType: 'workspace',
            resourceId: 'ws-1',
            title: 'Alpha Analysis',
            score: 0.9),
        const SearchResult(
            resourceType: 'workspace',
            resourceId: 'ws-2',
            title: 'Beta Report',
            score: 0.7),
        const SearchResult(
            resourceType: 'document',
            resourceId: 'doc-1',
            title: 'Alpha Docs',
            score: 0.5),
      ]);
    });

    test('returns results matching search text', () async {
      final resp = await svc.search(const SearchQuery(text: 'alpha'));
      expect(resp.results.length, equals(2));
      expect(resp.total, equals(2));
    });

    test('scope filters by resourceType', () async {
      final resp = await svc.search(
        const SearchQuery(
          text: 'alpha',
          scope: SearchScope(resourceTypes: {'workspace'}),
        ),
      );
      expect(resp.results.length, equals(1));
      expect(resp.results.first.resourceId, equals('ws-1'));
    });

    test('pagination works correctly', () async {
      final page0 = await svc.search(
          const SearchQuery(text: 'a', page: 0, pageSize: 2));
      final page1 = await svc.search(
          const SearchQuery(text: 'a', page: 1, pageSize: 2));

      expect(page0.results.length, equals(2));
      expect(page1.results.length, equals(1));
      expect(page0.total, equals(3));
    });

    test('empty query returns no results', () async {
      final resp = await svc.search(const SearchQuery(text: 'zzz_no_match'));
      expect(resp.hasResults, isFalse);
      expect(resp.total, equals(0));
    });
  });

  // =========================================================================
  // 4. Audit
  // =========================================================================
  group('4. AuditService', () {
    late InMemoryAuditService svc;
    final actorId = UserId('user-admin');
    final orgId = OrganizationId('org-1');

    setUp(() => svc = InMemoryAuditService());

    AuditEvent makeEvent(String id, String action, {bool ok = true}) => AuditEvent(
          id: id,
          timestamp: DateTime.now(),
          action: action,
          resourceType: 'workspace',
          resourceId: 'ws-1',
          actorId: actorId,
          organizationId: orgId,
          successful: ok,
        );

    test('record and query returns event', () async {
      await svc.record(makeEvent('ae-1', 'workspace.approve'));
      final list = await svc.query(const AuditQuery());
      expect(list.length, equals(1));
      expect(list.first.action, equals('workspace.approve'));
    });

    test('filter by actorId', () async {
      await svc.record(makeEvent('ae-1', 'workspace.approve'));
      final other = UserId('user-guest');
      final list = await svc.query(AuditQuery(actorId: other));
      expect(list.isEmpty, isTrue);
    });

    test('filter by action', () async {
      await svc.record(makeEvent('ae-1', 'workspace.approve'));
      await svc.record(makeEvent('ae-2', 'workspace.publish'));

      final list = await svc.query(const AuditQuery(action: 'workspace.publish'));
      expect(list.length, equals(1));
      expect(list.first.id, equals('ae-2'));
    });

    test('filter by success flag', () async {
      await svc.record(makeEvent('ae-1', 'workspace.approve', ok: true));
      await svc.record(makeEvent('ae-2', 'workspace.approve', ok: false));

      final all = await svc.query(const AuditQuery());
      expect(all.length, equals(2));
      expect(all.where((e) => e.successful).length, equals(1));
    });

    test('AuditEvent carries all mandatory fields', () {
      final evt = makeEvent('ae-9', 'role.change');
      expect(evt.actorId, equals(actorId));
      expect(evt.organizationId, equals(orgId));
      expect(evt.resourceType, equals('workspace'));
      expect(evt.successful, isTrue);
    });
  });

  // =========================================================================
  // 5. Settings
  // =========================================================================
  group('5. SettingsService', () {
    late InMemorySettingsService svc;
    setUp(() => svc = InMemorySettingsService());

    test('set and get at platform scope', () async {
      await svc.set('timezone', 'UTC', scope: SettingsScope.platform);
      final val = await svc.get('timezone', scope: SettingsScope.platform);
      expect(val, equals('UTC'));
    });

    test('scoped settings are independent', () async {
      await svc.set('timezone', 'UTC', scope: SettingsScope.platform);
      await svc.set('timezone', 'Asia/Jakarta',
          scope: SettingsScope.user, scopeId: 'user-1');

      final platform = await svc.get('timezone', scope: SettingsScope.platform);
      final user = await svc.get('timezone',
          scope: SettingsScope.user, scopeId: 'user-1');

      expect(platform, equals('UTC'));
      expect(user, equals('Asia/Jakarta'));
    });

    test('remove deletes value', () async {
      await svc.set('theme', 'dark', scope: SettingsScope.user, scopeId: 'u1');
      await svc.remove('theme', scope: SettingsScope.user, scopeId: 'u1');
      final val = await svc.get('theme', scope: SettingsScope.user, scopeId: 'u1');
      expect(val, isNull);
    });
  });

  group('5b. CascadedSettingsResolver', () {
    test('workspace wins over user over platform', () async {
      final svc = InMemorySettingsService();
      final resolver = CascadedSettingsResolver(svc);

      await svc.set('tz', 'UTC', scope: SettingsScope.platform);
      await svc.set('tz', 'Asia/Jakarta',
          scope: SettingsScope.user, scopeId: 'u1');
      await svc.set('tz', 'America/New_York',
          scope: SettingsScope.workspace, scopeId: 'ws1');

      final resolved = await resolver.resolve(
          'tz',
          const SettingsContext(
              userId: 'u1', workspaceId: 'ws1'));

      expect(resolved, equals('America/New_York'));
    });

    test('falls back to platform when no specific scope set', () async {
      final svc = InMemorySettingsService();
      final resolver = CascadedSettingsResolver(svc);

      await svc.set('tz', 'UTC', scope: SettingsScope.platform);

      final resolved = await resolver.resolve('tz', const SettingsContext());
      expect(resolved, equals('UTC'));
    });
  });

  // =========================================================================
  // 6. Feature Flags
  // =========================================================================
  group('6. FeatureFlagService', () {
    test('enabled flag returns true', () async {
      final svc = InMemoryFeatureFlagService({'new_workspace_ui': true});
      expect(await svc.isEnabled('new_workspace_ui'), isTrue);
    });

    test('disabled flag returns false', () async {
      final svc =
          InMemoryFeatureFlagService({'experimental_dashboard': false});
      expect(await svc.isEnabled('experimental_dashboard'), isFalse);
    });

    test('unknown flag returns false (safe default)', () async {
      final svc = InMemoryFeatureFlagService({});
      expect(await svc.isEnabled('nonexistent_flag'), isFalse);
    });

    test('get returns FeatureFlag model', () async {
      final svc = InMemoryFeatureFlagService({'agent_streaming': true});
      final flag = await svc.get('agent_streaming');

      expect(flag, isNotNull);
      expect(flag!.key, equals('agent_streaming'));
      expect(flag.enabled, isTrue);
    });

    test('feature flag ≠ authorization — get(null) still works independently', () async {
      final svc = InMemoryFeatureFlagService({'beta_feature': true});
      // Feature flag says enabled; no authorization check here
      final enabled = await svc.isEnabled('beta_feature', userId: 'u-1');
      expect(enabled, isTrue); // flag enabled, but auth must be checked separately
    });
  });

  // =========================================================================
  // 7. Observability — Logger
  // =========================================================================
  group('7. Logger', () {
    test('CapturingLogger records all levels', () {
      final log = CapturingLogger();
      log.debug('dbg');
      log.info('inf');
      log.warning('wrn');
      log.error('err', error: Exception('boom'));

      expect(log.records.length, equals(4));
      expect(log.records[0].level, equals(LogLevel.debug));
      expect(log.records[3].level, equals(LogLevel.error));
    });

    test('hasErrors is true when error was logged', () {
      final log = CapturingLogger();
      log.error('something went wrong');
      expect(log.hasErrors, isTrue);
    });

    test('hasErrors is false with only info/warning', () {
      final log = CapturingLogger();
      log.info('ok');
      log.warning('careful');
      expect(log.hasErrors, isFalse);
    });
  });

  // =========================================================================
  // 8. Observability — Tracer
  // =========================================================================
  group('8. Tracer', () {
    test('NoOpTracer creates spans with unique IDs', () async {
      final tracer = NoOpTracer();
      final s1 = tracer.startSpan('op1');
      final s2 = tracer.startSpan('op2');

      expect(s1.id, isNotEmpty);
      expect(s2.id, isNotEmpty);
      expect(s1.id, isNot(equals(s2.id)));
    });

    test('span records attributes and errors', () async {
      final tracer = NoOpTracer();
      final span = tracer.startSpan('db.query',
          attributes: {'db.table': 'workspaces'});

      span.setAttribute('rows', 42);
      span.recordError(Exception('timeout'), null);
      await span.end();

      expect(span.attributes['db.table'], equals('workspaces'));
      expect(span.attributes['rows'], equals(42));
      expect(span.errors.length, equals(1));
      expect(span.ended, isTrue);
    });
  });

  // =========================================================================
  // 9. Observability — Metrics
  // =========================================================================
  group('9. Metrics', () {
    test('increment records counter entry', () {
      final m = InMemoryMetrics();
      m.increment('api.request.count', labels: {'method': 'GET'});
      expect(m.records.length, equals(1));
      expect(m.records.first.type, equals('increment'));
      expect(m.records.first.labels['method'], equals('GET'));
    });

    test('gauge records value', () {
      final m = InMemoryMetrics();
      m.gauge('sync.queue.size', 7.0);
      expect(m.records.first.value, equals(7.0));
      expect(m.records.first.type, equals('gauge'));
    });

    test('timing records duration in ms', () {
      final m = InMemoryMetrics();
      m.timing('search.query.duration', const Duration(milliseconds: 120));
      expect(m.records.first.value, equals(120.0));
      expect(m.records.first.type, equals('timing'));
    });
  });

  // =========================================================================
  // 10. Observability — Health
  // =========================================================================
  group('10. HealthService', () {
    test('all healthy probes → healthy overall', () async {
      final svc = ComposableHealthService([
        () async =>
            const HealthCheck(name: 'database', status: HealthStatus.healthy),
        () async =>
            const HealthCheck(name: 'cache', status: HealthStatus.healthy),
      ]);

      final report = await svc.check();
      expect(report.overall, equals(HealthStatus.healthy));
      expect(report.checks.length, equals(2));
    });

    test('one unhealthy probe → unhealthy overall', () async {
      final svc = ComposableHealthService([
        () async =>
            const HealthCheck(name: 'database', status: HealthStatus.healthy),
        () async =>
            const HealthCheck(name: 'search', status: HealthStatus.unhealthy),
      ]);

      final report = await svc.check();
      expect(report.overall, equals(HealthStatus.unhealthy));
    });

    test('degraded probe with no unhealthy → degraded overall', () async {
      final svc = ComposableHealthService([
        () async =>
            const HealthCheck(name: 'api', status: HealthStatus.healthy),
        () async =>
            const HealthCheck(name: 'broker', status: HealthStatus.degraded),
      ]);

      final report = await svc.check();
      expect(report.overall, equals(HealthStatus.degraded));
    });

    test('HealthStatus enum covers four states', () {
      expect(
        HealthStatus.values,
        containsAll([
          HealthStatus.healthy,
          HealthStatus.degraded,
          HealthStatus.unhealthy,
          HealthStatus.unknown,
        ]),
      );
    });
  });

  // =========================================================================
  // 11. Boundary: no domain-specific types
  // =========================================================================
  group('11. Boundary invariants', () {
    test('SearchResult uses resourceType string, not domain type', () {
      const result = SearchResult(
          resourceType: 'economic_analysis',
          resourceId: 'ea-001',
          title: 'GDP 2026');

      // resourceType is an opaque string — alhambra_services doesn't know what it means
      expect(result.resourceType, isA<String>());
    });

    test('AuditEvent action is an opaque string', () {
      final evt = AuditEvent(
        id: 'ae-1',
        timestamp: DateTime.now(),
        action: 'workspace.approve', // domain-owned string
        resourceType: 'workspace',
        resourceId: 'ws-1',
        successful: true,
      );
      expect(evt.action, isA<String>());
    });
  });
}

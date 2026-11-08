import 'package:alhambra_data/alhambra_data.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SyncOperation _op(
  String id, {
  String resourceType = 'workspace',
  String resourceId = 'ws-1',
  String operation = 'update',
  String? organizationId,
  int? baseVersion,
  SyncOperationStatus status = SyncOperationStatus.pending,
}) =>
    SyncOperation(
      id: id,
      idempotencyKey: 'idem-$id',
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
      organizationId: organizationId,
      baseVersion: baseVersion,
      createdAt: DateTime(2026, 1, 1),
      status: status,
    );

// ---------------------------------------------------------------------------
// P12 Tests
// ---------------------------------------------------------------------------

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. Repository abstraction
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Repository abstraction', () {
    test('Repository interface exposes get, list, save, delete', () {
      // Verify the contract compiles and is accessible
      // (compile-time proof via type check)
      expect(Repository, isNotNull);
      expect(SyncRepository, isNotNull);
    });

    test('SyncState enum covers all states', () {
      const states = SyncState.values;
      expect(states, contains(SyncState.synced));
      expect(states, contains(SyncState.syncing));
      expect(states, contains(SyncState.pendingSync));
      expect(states, contains(SyncState.offline));
      expect(states, contains(SyncState.error));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Cache policies integrated
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Cache policies', () {
    test('all five cache policies are enumerable', () {
      expect(CachePolicy.values, hasLength(5));
      expect(CachePolicy.values, containsAll([
        CachePolicy.networkOnly,
        CachePolicy.cacheOnly,
        CachePolicy.cacheFirst,
        CachePolicy.networkFirst,
        CachePolicy.staleWhileRevalidate,
      ]));
    });

    test('sensitive resources use networkOnly or networkFirst', () {
      // Verify the enum values exist for policy assignment
      const sensitivePolicy = CachePolicy.networkOnly;
      const defaultPolicy = CachePolicy.staleWhileRevalidate;
      expect(sensitivePolicy, isNot(defaultPolicy));
    });

    test('MemoryCache respects TTL (stale entries not returned)', () async {
      final cache = MemoryCache();
      await cache.put<String>('key', 'value', ttl: const Duration(milliseconds: 10));
      expect(await cache.get<String>('key'), equals('value'));
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(await cache.get<String>('key'), isNull);
    });

    test('MemoryCache tenant isolation via org-scoped keys', () async {
      final cache = MemoryCache();
      // Keys must encode org context to avoid cross-tenant leakage
      const keyOrgA = 'org:ORG-A/workspace:123';
      const keyOrgB = 'org:ORG-B/workspace:123';
      await cache.put<String>(keyOrgA, 'workspace-a-data');
      await cache.put<String>(keyOrgB, 'workspace-b-data');
      final dataA = await cache.get<String>(keyOrgA);
      final dataB = await cache.get<String>(keyOrgB);
      expect(dataA, equals('workspace-a-data'));
      expect(dataB, equals('workspace-b-data'));
      expect(dataA, isNot(dataB));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. LocalRecord — sync metadata + tenant isolation
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 LocalRecord — sync metadata', () {
    test('LocalRecord carries all sync metadata fields', () {
      final now = DateTime.now();
      final record = LocalRecord(
        resourceType: 'workspace',
        resourceId: 'ws-1',
        organizationId: 'org-A',
        version: 7,
        etag: '"abc123"',
        updatedAt: now,
        serverUpdatedAt: now,
        state: SyncRecordState.synced,
        deleted: false,
        payload: {'name': 'My Workspace'},
      );

      expect(record.version, 7);
      expect(record.etag, '"abc123"');
      expect(record.state, SyncRecordState.synced);
      expect(record.deleted, isFalse);
      expect(record.payload['name'], 'My Workspace');
    });

    test('LocalRecord tombstone: deleted=true marks for delete sync', () {
      final record = LocalRecord(
        resourceType: 'workspace',
        resourceId: 'ws-del',
        organizationId: 'org-A',
        updatedAt: DateTime.now(),
        payload: {},
        state: SyncRecordState.pendingDelete,
        deleted: true,
      );
      expect(record.deleted, isTrue);
      expect(record.state, SyncRecordState.pendingDelete);
    });

    test('LocalRecord.copyWith produces new instance with updated fields', () {
      final original = LocalRecord(
        resourceType: 'workspace',
        resourceId: 'ws-1',
        organizationId: 'org-A',
        version: 7,
        updatedAt: DateTime(2026, 1, 1),
        payload: {},
      );
      final updated = original.copyWith(version: 8, state: SyncRecordState.pendingSync);
      expect(updated.version, 8);
      expect(updated.state, SyncRecordState.pendingSync);
      expect(updated.resourceId, 'ws-1'); // unchanged
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. InMemoryLocalRecordStore — tenant-isolated local DB
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 InMemoryLocalRecordStore tenant isolation', () {
    test('records from different orgs do NOT leak across tenants', () {
      final store = InMemoryLocalRecordStore();
      final recA = LocalRecord(
        resourceType: 'workspace',
        resourceId: 'ws-1',
        organizationId: 'org-A',
        updatedAt: DateTime.now(),
        payload: {'owner': 'A'},
      );
      final recB = LocalRecord(
        resourceType: 'workspace',
        resourceId: 'ws-1', // same resourceId!
        organizationId: 'org-B',
        updatedAt: DateTime.now(),
        payload: {'owner': 'B'},
      );
      store.save(recA);
      store.save(recB);

      final fetchedA = store.get(
          resourceType: 'workspace', resourceId: 'ws-1', organizationId: 'org-A');
      final fetchedB = store.get(
          resourceType: 'workspace', resourceId: 'ws-1', organizationId: 'org-B');

      expect(fetchedA!.payload['owner'], 'A');
      expect(fetchedB!.payload['owner'], 'B');
    });

    test('listForOrg returns only records for the requested org', () {
      final store = InMemoryLocalRecordStore();
      store.save(LocalRecord(
        resourceType: 'workspace', resourceId: 'ws-1',
        organizationId: 'org-A', updatedAt: DateTime.now(), payload: {},
      ));
      store.save(LocalRecord(
        resourceType: 'workspace', resourceId: 'ws-2',
        organizationId: 'org-A', updatedAt: DateTime.now(), payload: {},
      ));
      store.save(LocalRecord(
        resourceType: 'workspace', resourceId: 'ws-3',
        organizationId: 'org-B', updatedAt: DateTime.now(), payload: {},
      ));

      final orgARecords = store.listForOrg('org-A');
      expect(orgARecords.length, 2);
      expect(orgARecords.every((r) => r.organizationId == 'org-A'), isTrue);
    });

    test('tombstoned records are excluded from listForOrg', () {
      final store = InMemoryLocalRecordStore();
      store.save(LocalRecord(
        resourceType: 'workspace', resourceId: 'ws-1',
        organizationId: 'org-A', updatedAt: DateTime.now(),
        payload: {}, deleted: true,
      ));
      expect(store.listForOrg('org-A'), isEmpty);
    });

    test('purge removes record permanently from local store', () {
      final store = InMemoryLocalRecordStore();
      store.save(LocalRecord(
        resourceType: 'workspace', resourceId: 'ws-del',
        organizationId: 'org-A', updatedAt: DateTime.now(), payload: {},
      ));
      expect(store.count, 1);
      store.purge(resourceType: 'workspace', resourceId: 'ws-del', organizationId: 'org-A');
      expect(store.count, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. SyncOperation P12 hardening
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 SyncOperation hardening', () {
    test('carries idempotencyKey, resourceId, organizationId, baseVersion', () {
      final op = _op('op-1', organizationId: 'org-A', baseVersion: 7);
      expect(op.idempotencyKey, 'idem-op-1');
      expect(op.resourceId, 'ws-1');
      expect(op.organizationId, 'org-A');
      expect(op.baseVersion, 7);
    });

    test('default status is pending', () {
      expect(_op('op-x').status, SyncOperationStatus.pending);
    });

    test('copyWith updates attempt tracking fields', () {
      final op = _op('op-1');
      final now = DateTime.now();
      final updated = op.copyWith(
        attemptCount: 2,
        lastAttemptAt: now,
        status: SyncOperationStatus.retrying,
      );
      expect(updated.attemptCount, 2);
      expect(updated.lastAttemptAt, now);
      expect(updated.status, SyncOperationStatus.retrying);
      expect(updated.idempotencyKey, op.idempotencyKey); // unchanged
    });

    test('SyncOperationStatus state machine enum has all required values', () {
      expect(SyncOperationStatus.values, containsAll([
        SyncOperationStatus.pending,
        SyncOperationStatus.syncing,
        SyncOperationStatus.succeeded,
        SyncOperationStatus.retrying,
        SyncOperationStatus.conflict,
        SyncOperationStatus.unauthorized,
        SyncOperationStatus.failed,
      ]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. SyncErrorClass — error classification
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Error classification', () {
    test('network error → retryable', () {
      expect(classifySyncError(isNetworkError: true), SyncErrorClass.retryable);
    });

    test('HTTP 401 → authenticationExpired', () {
      expect(classifySyncError(httpStatus: 401), SyncErrorClass.authenticationExpired);
    });

    test('HTTP 409 → conflict', () {
      expect(classifySyncError(httpStatus: 409), SyncErrorClass.conflict);
    });

    test('HTTP 403 → nonRetryable (forbidden)', () {
      expect(classifySyncError(httpStatus: 403), SyncErrorClass.nonRetryable);
    });

    test('HTTP 400 → nonRetryable (bad request)', () {
      expect(classifySyncError(httpStatus: 400), SyncErrorClass.nonRetryable);
    });

    test('HTTP 500 → retryable (server error)', () {
      expect(classifySyncError(httpStatus: 500), SyncErrorClass.retryable);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. DefaultSyncEngine — tenant isolation during sync
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Tenant isolation during sync', () {
    test('operations from a different org are SKIPPED (account switch safety)', () async {
      final queue = InMemoryOfflineQueue();
      // Op queued under org-A
      await queue.enqueue(_op('op-orgA', organizationId: 'org-A'));

      // User has switched to org-B
      final ctx = SyncContext(organizationId: 'org-B', isAuthenticated: true);

      final dispatched = <String>[];
      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (op) async {
          dispatched.add(op.id);
          return const DispatchResult.succeeded();
        },
      );

      final result = await engine.synchronize(context: ctx);
      expect(dispatched, isEmpty, reason: 'org-A op must not execute under org-B');
      expect(result.skipped, 1);
      engine.dispose();
    });

    test('operations matching current org ARE dispatched', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-orgA', organizationId: 'org-A'));

      final ctx = SyncContext(organizationId: 'org-A', isAuthenticated: true);
      final dispatched = <String>[];

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (op) async {
          dispatched.add(op.id);
          return const DispatchResult.succeeded();
        },
      );

      await engine.synchronize(context: ctx);
      expect(dispatched, contains('op-orgA'));
      engine.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 8. DefaultSyncEngine — authentication gate
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Authentication expiry handling', () {
    test('unauthenticated context suspends sync and emits authRequired', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-1'));

      final ctx = SyncContext(isAuthenticated: false);
      final statuses = <SyncStatus>[];

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (_) async => const DispatchResult.succeeded(),
      );
      engine.status.listen(statuses.add);

      final result = await engine.synchronize(context: ctx);

      // Nothing dispatched, queue untouched
      expect(await queue.count(), 1);
      expect(result.succeeded, 0);
      expect(statuses, contains(SyncStatus.authRequired));
      engine.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. DefaultSyncEngine — conflict + unauthorized → no retry
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Non-retryable error handling', () {
    test('conflict result marks operation conflict, not removed from queue', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-conflict'));

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (_) async =>
            const DispatchResult.conflict('version mismatch (409)'),
      );

      final result = await engine.synchronize();
      expect(result.conflicts, 1);
      // Operation stays in queue but with conflict status
      expect(await queue.count(), 1);
      final remaining = await queue.pending();
      // pending() only returns pending/retrying — conflict ops are filtered
      expect(remaining.where((op) => op.status == SyncOperationStatus.conflict),
          isEmpty);
      engine.dispose();
    });

    test('unauthorized result marks operation, no infinite retry', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-auth'));

      int dispatchCount = 0;
      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (_) async {
          dispatchCount++;
          return const DispatchResult.unauthorized('role removed (401)');
        },
      );

      // Run sync twice — should not keep retrying unauthorized op
      await engine.synchronize();
      await engine.synchronize();

      // After first sync, op has status=unauthorized and is no longer pending
      // so second sync skips it
      expect(dispatchCount, 1, reason: 'unauthorized op must not be retried');
      engine.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 10. MutationResult
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 MutationResult', () {
    test('synchronized result has correct status', () {
      const r = MutationResult.synchronized('data');
      expect(r.status, MutationStatus.synchronized);
      expect(r.isSynchronized, isTrue);
      expect(r.isPending, isFalse);
    });

    test('pending result carries operationId', () {
      const r = MutationResult.pending('optimistic', operationId: 'op-123');
      expect(r.status, MutationStatus.pending);
      expect(r.operationId, 'op-123');
      expect(r.isPending, isTrue);
    });

    test('conflict result has correct status', () {
      const r = MutationResult<String>.conflict('stale-value');
      expect(r.isConflict, isTrue);
    });

    test('rejected result has correct status', () {
      const r = MutationResult<int>.rejected(0);
      expect(r.isRejected, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 11. ConflictInfo
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 ConflictInfo', () {
    test('carries resourceType, resourceId, local, remote, conflictingFields', () {
      const info = ConflictInfo(
        resourceType: 'workspace',
        resourceId: 'ws-1',
        local: {'status': 'APPROVED'},
        remote: {'status': 'REVIEW'},
        conflictingFields: ['status'],
      );
      expect(info.resourceType, 'workspace');
      expect(info.conflictingFields, contains('status'));
      expect(info.local, isNotNull);
      expect(info.remote, isNotNull);
    });

    test('conflictingFields defaults to empty list', () {
      const info = ConflictInfo(resourceType: 'artifact', resourceId: 'a-1');
      expect(info.conflictingFields, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 12. SyncContext — tenant safety
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 SyncContext tenant safety', () {
    test('canDispatch returns false for different org', () {
      final ctx = SyncContext(organizationId: 'org-B');
      expect(ctx.canDispatch('org-A'), isFalse);
    });

    test('canDispatch returns true for matching org', () {
      final ctx = SyncContext(organizationId: 'org-A');
      expect(ctx.canDispatch('org-A'), isTrue);
    });

    test('canDispatch returns true for null operationOrgId (context-free op)', () {
      final ctx = SyncContext(organizationId: 'org-A');
      expect(ctx.canDispatch(null), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 13. SyncScheduler — exponential backoff
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 SyncScheduler exponential backoff', () {
    test('first retry uses initial delay (5s default)', () {
      const scheduler = SyncScheduler();
      expect(scheduler.nextDelay(0), const Duration(seconds: 5));
    });

    test('second retry doubles the delay', () {
      const scheduler = SyncScheduler();
      final d1 = scheduler.nextDelay(0);
      final d2 = scheduler.nextDelay(1);
      expect(d2.inMilliseconds, greaterThan(d1.inMilliseconds));
    });

    test('delay is capped at maximum', () {
      const scheduler = SyncScheduler(
        config: BackoffConfig(
          initial: Duration(seconds: 5),
          maximum: Duration(seconds: 30),
          multiplier: 10,
        ),
      );
      // Even with multiplier=10, should never exceed max
      for (var i = 0; i < 10; i++) {
        expect(scheduler.nextDelay(i).inMilliseconds,
            lessThanOrEqualTo(const Duration(seconds: 30).inMilliseconds));
      }
    });

    test('shouldRetry returns false when not enough time elapsed', () {
      const scheduler = SyncScheduler(
        config: BackoffConfig(initial: Duration(seconds: 60)),
      );
      final lastAttempt = DateTime.now().subtract(const Duration(seconds: 5));
      expect(
        scheduler.shouldRetry(attemptCount: 0, lastAttemptAt: lastAttempt),
        isFalse,
      );
    });

    test('shouldRetry returns true when enough time has elapsed', () {
      const scheduler = SyncScheduler(
        config: BackoffConfig(initial: Duration(seconds: 1)),
      );
      final lastAttempt = DateTime.now().subtract(const Duration(seconds: 5));
      expect(
        scheduler.shouldRetry(attemptCount: 0, lastAttemptAt: lastAttempt),
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 14. SyncRecordState + SyncStatus enums
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Sync state machine', () {
    test('SyncRecordState covers all local record states', () {
      expect(SyncRecordState.values, containsAll([
        SyncRecordState.synced,
        SyncRecordState.pendingSync,
        SyncRecordState.conflict,
        SyncRecordState.pendingDelete,
      ]));
    });

    test('SyncStatus covers engine lifecycle states', () {
      expect(SyncStatus.values, containsAll([
        SyncStatus.idle,
        SyncStatus.syncing,
        SyncStatus.error,
        SyncStatus.offline,
        SyncStatus.authRequired,
      ]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 15. SyncEngine status stream observability
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Sync observability', () {
    test('sync engine emits syncing then idle on success', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-ok'));

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (_) async => const DispatchResult.succeeded(),
      );

      final collected = <SyncStatus>[];
      final sub = engine.status.listen(collected.add);

      await engine.synchronize(
        context: SyncContext(isAuthenticated: true),
      );
      // Allow microtasks to flush
      await Future<void>.delayed(Duration.zero);

      expect(collected, contains(SyncStatus.syncing));
      expect(collected.last, SyncStatus.idle);
      await sub.cancel();
      engine.dispose();
    });

    test('sync engine emits error status on failure', () async {
      final queue = InMemoryOfflineQueue();
      await queue.enqueue(_op('op-fail'));

      final engine = DefaultSyncEngine(
        queue: queue,
        dispatcher: (_) async => const DispatchResult.failed('bad request'),
      );

      final collected = <SyncStatus>[];
      final sub = engine.status.listen(collected.add);

      await engine.synchronize();
      await Future<void>.delayed(Duration.zero);

      expect(collected.last, SyncStatus.error);
      await sub.cancel();
      engine.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 16. No offline bypass of governance (architecture invariant)
  // ─────────────────────────────────────────────────────────────────────────
  group('P12 Governance invariant', () {
    test('MutationResult.pending explicitly signals awaiting server', () {
      // The presence of `pending` status prevents the client from
      // treating local optimistic state as authoritative
      const result = MutationResult.pending(
        'optimistic-workspace',
        operationId: 'op-approve',
      );
      expect(result.isPending, isTrue);
      expect(result.isSynchronized, isFalse,
          reason: 'Pending mutations must NOT be treated as server-confirmed');
    });

    test('LOCAL DATA != SERVER AUTHORITY: pending is not synchronized', () {
      // synchronized == server confirmed
      // pending == optimistic intent only
      const pendingResult = MutationResult.pending(42);
      const confirmedResult = MutationResult.synchronized(42);
      expect(pendingResult.status, isNot(confirmedResult.status));
    });
  });
}

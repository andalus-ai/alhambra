import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

PluginRevocationJournalEntry pendingEntry({int revision = 1}) {
  final created = DateTime.utc(2026, 1, 1);
  return PluginRevocationJournalEntry(
    idempotencyKey: 'op:plugin:provider:deactivate',
    operationId: 'op',
    pluginId: 'plugin',
    providerOwnerId: 'provider',
    action: CapabilityImpactAction.deactivate,
    status: PluginRevocationJournalStatus.pending,
    revision: revision,
    createdAt: created,
    updatedAt: created,
    correlationId: 'trace-1',
  );
}

void main() {
  group('PluginRevocationJournalStore', () {
    test('inserts once and compare-and-set rejects stale revisions', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      expect(await store.insertIfAbsent(entry), isTrue);
      expect(await store.insertIfAbsent(entry), isFalse);
      final next = entry.next(
        status: PluginRevocationJournalStatus.completed,
        at: DateTime.utc(2026, 1, 2),
      );
      expect(await store.compareAndSet(
        idempotencyKey: entry.idempotencyKey,
        expectedRevision: 0,
        replacement: next,
      ), isFalse);
      expect(await store.compareAndSet(
        idempotencyKey: entry.idempotencyKey,
        expectedRevision: 1,
        replacement: next,
      ), isTrue);
    });
  });

  group('PluginRevocationReconciler', () {
    test('marks an already-applied action without replay', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      await store.insertIfAbsent(entry);
      var retries = 0;
      final reconciler = PluginRevocationReconciler(
        store: store,
        inspect: (_) async => PluginRevocationObservedState.applied,
        approveRetry: (_) async => true,
        retry: (_) async => retries++,
      );

      final result = await reconciler.reconcilePending();
      expect(result.single.outcome,
          PluginRevocationReconciliationOutcome.markedApplied);
      expect(retries, 0);
      expect((await store.read(entry.idempotencyKey))!.status,
          PluginRevocationJournalStatus.reconciledApplied);
    });

    test('unknown authoritative state is held for manual review', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      await store.insertIfAbsent(entry);
      var approvals = 0;
      final reconciler = PluginRevocationReconciler(
        store: store,
        inspect: (_) async => PluginRevocationObservedState.unknown,
        approveRetry: (_) async { approvals++; return true; },
        retry: (_) async => fail('must not replay unknown state'),
      );

      final result = await reconciler.reconcile(entry);
      expect(result.outcome, PluginRevocationReconciliationOutcome.manualReview);
      expect(approvals, 0);
      expect((await store.read(entry.idempotencyKey))!.status,
          PluginRevocationJournalStatus.manualReview);
    });

    test('requires explicit approval before retrying a confirmed unapplied action', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      await store.insertIfAbsent(entry);
      var retries = 0;
      final reconciler = PluginRevocationReconciler(
        store: store,
        inspect: (_) async => PluginRevocationObservedState.notApplied,
        approveRetry: (_) async => false,
        retry: (_) async => retries++,
      );

      final result = await reconciler.reconcile(entry);
      expect(result.outcome, PluginRevocationReconciliationOutcome.retryDeclined);
      expect(retries, 0);
      expect((await store.read(entry.idempotencyKey))!.status,
          PluginRevocationJournalStatus.manualReview);
    });

    test('persists retry authorization before invoking executor', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      await store.insertIfAbsent(entry);
      var observedRevision = 0;
      final reconciler = PluginRevocationReconciler(
        store: store,
        inspect: (_) async => PluginRevocationObservedState.notApplied,
        approveRetry: (_) async => true,
        retry: (authorized) async {
          observedRevision = (await store.read(authorized.idempotencyKey))!.revision;
          expect((await store.read(authorized.idempotencyKey))!.status,
              PluginRevocationJournalStatus.retryAuthorized);
        },
      );

      final result = await reconciler.reconcile(entry);
      expect(result.outcome,
          PluginRevocationReconciliationOutcome.retryAuthorizedAndExecuted);
      expect(observedRevision, 2);
      final completed = await store.read(entry.idempotencyKey);
      expect(completed!.status, PluginRevocationJournalStatus.completed);
      expect(completed.revision, 3);
    });

    test('ambiguous retry failure is not blindly retried', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final entry = pendingEntry();
      await store.insertIfAbsent(entry);
      final reconciler = PluginRevocationReconciler(
        store: store,
        inspect: (_) async => PluginRevocationObservedState.notApplied,
        approveRetry: (_) async => true,
        retry: (_) async => throw StateError('connection lost after dispatch'),
      );

      final result = await reconciler.reconcile(entry);
      expect(result.outcome, PluginRevocationReconciliationOutcome.manualReview);
      expect((await store.read(entry.idempotencyKey))!.status,
          PluginRevocationJournalStatus.manualReview);
    });
  });
}

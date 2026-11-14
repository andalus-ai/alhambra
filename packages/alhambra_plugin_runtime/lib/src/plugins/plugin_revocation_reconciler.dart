import 'plugin_revocation_journal.dart';

enum PluginRevocationObservedState { applied, notApplied, unknown }
enum PluginRevocationReconciliationOutcome {
  markedApplied, retryAuthorizedAndExecuted, retryDeclined, manualReview,
  alreadyTerminal, concurrentUpdate,
}
typedef PluginRevocationStateInspector = Future<PluginRevocationObservedState> Function(PluginRevocationJournalEntry entry);
typedef PluginRevocationRetryApproval = Future<bool> Function(PluginRevocationJournalEntry entry);
typedef PluginRevocationRetryExecutor = Future<void> Function(PluginRevocationJournalEntry entry);

/// Reconciles interrupted actions. Pending records are never blindly replayed.
class PluginRevocationReconciler {
  final PluginRevocationJournalStore store;
  final PluginRevocationStateInspector inspect;
  final PluginRevocationRetryApproval approveRetry;
  final PluginRevocationRetryExecutor retry;
  final DateTime Function() clock;

  PluginRevocationReconciler({
    required this.store, required this.inspect,
    required this.approveRetry, required this.retry,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<List<PluginRevocationReconciliationResult>> reconcilePending() async {
    final pending = (await store.readAll())
        .where((entry) => entry.requiresReconciliation).toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time != 0 ? time : a.idempotencyKey.compareTo(b.idempotencyKey);
      });
    final results = <PluginRevocationReconciliationResult>[];
    for (final entry in pending) { results.add(await reconcile(entry)); }
    return List.unmodifiable(results);
  }

  Future<PluginRevocationReconciliationResult> reconcile(PluginRevocationJournalEntry entry) async {
    final current = await store.read(entry.idempotencyKey);
    if (current == null || current.revision != entry.revision) {
      return PluginRevocationReconciliationResult(entry.idempotencyKey, PluginRevocationReconciliationOutcome.concurrentUpdate);
    }
    if (!entry.requiresReconciliation) {
      return PluginRevocationReconciliationResult(entry.idempotencyKey, PluginRevocationReconciliationOutcome.alreadyTerminal);
    }
    final observed = await inspect(entry);
    if (observed == PluginRevocationObservedState.applied) {
      final saved = await _save(entry, PluginRevocationJournalStatus.reconciledApplied,
        'Authoritative host inspection confirmed the action is already applied.');
      return PluginRevocationReconciliationResult(entry.idempotencyKey,
        saved ? PluginRevocationReconciliationOutcome.markedApplied : PluginRevocationReconciliationOutcome.concurrentUpdate);
    }
    if (observed == PluginRevocationObservedState.unknown) {
      await _save(entry, PluginRevocationJournalStatus.manualReview,
        'Authoritative host state is unknown; automatic replay is unsafe.');
      return PluginRevocationReconciliationResult(entry.idempotencyKey, PluginRevocationReconciliationOutcome.manualReview);
    }
    if (!await approveRetry(entry)) {
      final saved = await _save(entry, PluginRevocationJournalStatus.manualReview,
        'Action is not applied; host declined retry authorization.');
      return PluginRevocationReconciliationResult(entry.idempotencyKey,
        saved ? PluginRevocationReconciliationOutcome.retryDeclined : PluginRevocationReconciliationOutcome.concurrentUpdate);
    }
    final authorized = entry.next(status: PluginRevocationJournalStatus.retryAuthorized,
      at: clock(), detail: 'Host explicitly authorized retry after observing no side effect.');
    if (!await store.compareAndSet(idempotencyKey: entry.idempotencyKey,
      expectedRevision: entry.revision, replacement: authorized)) {
      return PluginRevocationReconciliationResult(entry.idempotencyKey, PluginRevocationReconciliationOutcome.concurrentUpdate);
    }
    try {
      await retry(authorized);
      final completed = authorized.next(status: PluginRevocationJournalStatus.completed,
        at: clock(), detail: 'Explicitly authorized retry completed.');
      final saved = await store.compareAndSet(idempotencyKey: entry.idempotencyKey,
        expectedRevision: authorized.revision, replacement: completed);
      return PluginRevocationReconciliationResult(entry.idempotencyKey,
        saved ? PluginRevocationReconciliationOutcome.retryAuthorizedAndExecuted : PluginRevocationReconciliationOutcome.concurrentUpdate);
    } catch (error) {
      await _save(authorized, PluginRevocationJournalStatus.manualReview,
        'Retry outcome is ambiguous (' + error.runtimeType.toString() + '); inspect authoritative state.');
      return PluginRevocationReconciliationResult(entry.idempotencyKey, PluginRevocationReconciliationOutcome.manualReview);
    }
  }

  Future<bool> _save(PluginRevocationJournalEntry entry, PluginRevocationJournalStatus status, String detail) =>
      store.compareAndSet(idempotencyKey: entry.idempotencyKey,
        expectedRevision: entry.revision,
        replacement: entry.next(status: status, at: clock(), detail: detail));
}

final class PluginRevocationReconciliationResult {
  final String idempotencyKey;
  final PluginRevocationReconciliationOutcome outcome;
  const PluginRevocationReconciliationResult(this.idempotencyKey, this.outcome);
}

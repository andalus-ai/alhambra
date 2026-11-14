import 'plugin_revocation_journal.dart';
import 'plugin_revocation_outbox.dart';

/// Immutable operational view of durable revocation state.
///
/// This projection is intentionally read-only. It does not claim outbox
/// messages, reconcile journal entries, or invoke plugin lifecycle methods.
final class PluginRevocationOperationsSnapshot {
  final DateTime capturedAt;
  final List<PluginRevocationJournalEntry> journalEntries;
  final List<PluginRevocationOutboxMessage> outboxMessages;
  final Map<PluginRevocationJournalStatus, int> journalCounts;
  final Map<PluginRevocationOutboxState, int> outboxCounts;
  final int unresolvedJournalEntries;
  final int overduePendingMessages;
  final int expiredLeases;

  PluginRevocationOperationsSnapshot({
    required this.capturedAt,
    required Iterable<PluginRevocationJournalEntry> journalEntries,
    required Iterable<PluginRevocationOutboxMessage> outboxMessages,
    required this.journalCounts,
    required this.outboxCounts,
    required this.unresolvedJournalEntries,
    required this.overduePendingMessages,
    required this.expiredLeases,
  })  : journalEntries = List.unmodifiable(journalEntries),
        outboxMessages = List.unmodifiable(outboxMessages),
        journalCounts = Map.unmodifiable(journalCounts),
        outboxCounts = Map.unmodifiable(outboxCounts);

  int get totalJournalEntries => journalEntries.length;
  int get totalOutboxMessages => outboxMessages.length;
  int get pendingOutboxMessages =>
      outboxCounts[PluginRevocationOutboxState.pending] ?? 0;
  int get leasedOutboxMessages =>
      outboxCounts[PluginRevocationOutboxState.leased] ?? 0;
  int get deliveredOutboxMessages =>
      outboxCounts[PluginRevocationOutboxState.delivered] ?? 0;
  int get deadLetterOutboxMessages =>
      outboxCounts[PluginRevocationOutboxState.deadLetter] ?? 0;
}

/// Builds a consistent-in-process, read-only operational projection.
///
/// The two underlying reads may observe different committed instants when
/// other workers are writing concurrently. Consumers must treat this as an
/// operational snapshot, not a cross-table serializable database snapshot.
/// Database adapters can add a stronger snapshot API in a later revision.
final class PluginRevocationOperationsService {
  final PluginRevocationJournalStore journalStore;
  final PluginRevocationOutboxInspectionStore outboxStore;
  final DateTime Function() clock;

  PluginRevocationOperationsService({
    required this.journalStore,
    required this.outboxStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationOperationsSnapshot> inspect() async {
    final capturedAt = clock().toUtc();
    final results = await Future.wait<Object>([
      journalStore.readAll(),
      outboxStore.readAllOutbox(),
    ]);
    final journals = (results[0] as List<PluginRevocationJournalEntry>).toList()
      ..sort((a, b) {
        final updated = b.updatedAt.compareTo(a.updatedAt);
        return updated != 0
            ? updated
            : a.idempotencyKey.compareTo(b.idempotencyKey);
      });
    final messages = (results[1] as List<PluginRevocationOutboxMessage>).toList()
      ..sort((a, b) {
        final occurred = b.event.occurredAt.compareTo(a.event.occurredAt);
        return occurred != 0
            ? occurred
            : a.event.eventId.compareTo(b.event.eventId);
      });

    final journalKeys = <String>{};
    for (final entry in journals) {
      if (!journalKeys.add(entry.idempotencyKey)) {
        throw StateError('Journal inspection returned duplicate idempotency keys.');
      }
    }
    final eventIds = <String>{};
    for (final message in messages) {
      if (!eventIds.add(message.event.eventId)) {
        throw StateError('Outbox inspection returned duplicate event IDs.');
      }
    }

    final journalCounts = <PluginRevocationJournalStatus, int>{
      for (final status in PluginRevocationJournalStatus.values)
        status: journals.where((entry) => entry.status == status).length,
    };
    final outboxCounts = <PluginRevocationOutboxState, int>{
      for (final state in PluginRevocationOutboxState.values)
        state: messages.where((message) => message.state == state).length,
    };
    final unresolved = journals.where((entry) => entry.requiresReconciliation).length;
    final overdue = messages.where((message) =>
        message.state == PluginRevocationOutboxState.pending &&
        !message.nextAttemptAt.isAfter(capturedAt)).length;
    final expired = messages.where((message) =>
        message.state == PluginRevocationOutboxState.leased &&
        message.leaseUntil != null &&
        !message.leaseUntil!.isAfter(capturedAt)).length;

    return PluginRevocationOperationsSnapshot(
      capturedAt: capturedAt,
      journalEntries: journals,
      outboxMessages: messages,
      journalCounts: journalCounts,
      outboxCounts: outboxCounts,
      unresolvedJournalEntries: unresolved,
      overduePendingMessages: overdue,
      expiredLeases: expired,
    );
  }
}

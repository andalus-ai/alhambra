import 'plugin_revocation_coordinator.dart';

/// Stable, sanitized audit payload created when a revocation reaches an outcome.
final class PluginRevocationAuditEvent {
  final String eventId;
  final String idempotencyKey;
  final String operationId;
  final String pluginId;
  final String providerOwnerId;
  final String action;
  final String outcome;
  final DateTime occurredAt;
  final String? detail;

  const PluginRevocationAuditEvent({
    required this.eventId,
    required this.idempotencyKey,
    required this.operationId,
    required this.pluginId,
    required this.providerOwnerId,
    required this.action,
    required this.outcome,
    required this.occurredAt,
    this.detail,
  });
}

enum PluginRevocationOutboxState { pending, leased, delivered, deadLetter }

/// Durable outbox envelope. Lease ownership is explicit to prevent stale
/// workers from acknowledging a message claimed by a newer worker.
final class PluginRevocationOutboxMessage {
  final PluginRevocationAuditEvent event;
  final PluginRevocationOutboxState state;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? leaseOwner;
  final String? leaseToken;
  final DateTime? leaseUntil;
  final String? lastErrorCode;

  const PluginRevocationOutboxMessage({
    required this.event,
    required this.state,
    required this.attempts,
    required this.nextAttemptAt,
    this.leaseOwner,
    this.leaseToken,
    this.leaseUntil,
    this.lastErrorCode,
  });
}

/// Combined transaction boundary for execution outcome + outbox insertion.
///
/// A production implementation MUST commit both changes in one database
/// transaction. Implementing these as two independent writes defeats the
/// transactional-outbox guarantee.
/// Persistence contract for leased outbox delivery.
abstract interface class PluginRevocationOutboxStore {
  Future<List<PluginRevocationOutboxMessage>> claim({
    required String workerId,
    required DateTime now,
    required Duration leaseDuration,
    required int limit,
  });

  Future<bool> markDelivered({
    required String eventId,
    required String leaseToken,
    required DateTime deliveredAt,
  });

  Future<bool> reschedule({
    required String eventId,
    required String leaseToken,
    required DateTime nextAttemptAt,
    required String errorCode,
    required int maxAttempts,
  });
}

/// Single-isolate reference implementation for tests only. A real adapter
/// needs database transactions, uniqueness constraints and row-level claims.
class InMemoryTransactionalPluginRevocationStore
    implements TransactionalPluginRevocationStore, PluginRevocationOutboxStore {
  final Map<String, PluginRevocationExecutionRecord> _executions = {};
  final Map<String, PluginRevocationOutboxMessage> _messages = {};

  @override
  Future<PluginRevocationExecutionRecord?> read(String idempotencyKey) async =>
      _executions[idempotencyKey];

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) async {
    if (_executions.containsKey(record.idempotencyKey)) return false;
    _executions[record.idempotencyKey] = record;
    return true;
  }

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) =>
      completeAndEnqueue(record);

  @override
  Future<void> append(PluginRevocationExecutionRecord record) =>
      _enqueue(record);

  @override
  Future<void> completeAndEnqueue(PluginRevocationExecutionRecord record) async {
    if (!_executions.containsKey(record.idempotencyKey)) {
      throw StateError('Cannot complete an unclaimed revocation operation.');
    }
    // No await between these map writes: atomic within this single isolate.
    _executions[record.idempotencyKey] = record;
    _enqueueSync(record);
  }

  void _enqueue(PluginRevocationExecutionRecord record) => _enqueueSync(record);

  void _enqueueSync(PluginRevocationExecutionRecord record) {
    final eventId = '${record.idempotencyKey}:terminal';
    _messages.putIfAbsent(eventId, () {
      final event = PluginRevocationAuditEvent(
        eventId: eventId,
        idempotencyKey: record.idempotencyKey,
        operationId: record.operationId,
        pluginId: record.pluginId,
        providerOwnerId: record.providerOwnerId,
        action: record.action.name,
        outcome: record.status.name,
        occurredAt: record.updatedAt,
        detail: record.detail,
      );
      return PluginRevocationOutboxMessage(
        event: event,
        state: PluginRevocationOutboxState.pending,
        attempts: 0,
        nextAttemptAt: record.updatedAt,
      );
    });
  }

  @override
  Future<List<PluginRevocationOutboxMessage>> claim({
    required String workerId,
    required DateTime now,
    required Duration leaseDuration,
    required int limit,
  }) async {
    if (workerId.trim().isEmpty || leaseDuration <= Duration.zero || limit < 1) {
      throw ArgumentError('workerId, positive leaseDuration and limit are required.');
    }
    final instant = now.toUtc();
    final candidates = _messages.values.where((message) {
      if (message.state == PluginRevocationOutboxState.delivered ||
          message.state == PluginRevocationOutboxState.deadLetter) return false;
      if (message.state == PluginRevocationOutboxState.pending) {
        return !message.nextAttemptAt.isAfter(instant);
      }
      return message.leaseUntil != null && !message.leaseUntil!.isAfter(instant);
    }).toList()
      ..sort((a, b) => a.event.occurredAt.compareTo(b.event.occurredAt));

    final claimed = <PluginRevocationOutboxMessage>[];
    for (final current in candidates.take(limit)) {
      final attempts = current.attempts + 1;
      final token = '$workerId:${current.event.eventId}:$attempts';
      final leased = PluginRevocationOutboxMessage(
        event: current.event,
        state: PluginRevocationOutboxState.leased,
        attempts: attempts,
        nextAttemptAt: current.nextAttemptAt,
        leaseOwner: workerId,
        leaseToken: token,
        leaseUntil: instant.add(leaseDuration),
        lastErrorCode: current.lastErrorCode,
      );
      _messages[current.event.eventId] = leased;
      claimed.add(leased);
    }
    return List.unmodifiable(claimed);
  }

  @override
  Future<bool> markDelivered({
    required String eventId,
    required String leaseToken,
    required DateTime deliveredAt,
  }) async {
    final current = _messages[eventId];
    if (current == null || current.state != PluginRevocationOutboxState.leased ||
        current.leaseToken != leaseToken) return false;
    _messages[eventId] = PluginRevocationOutboxMessage(
      event: current.event,
      state: PluginRevocationOutboxState.delivered,
      attempts: current.attempts,
      nextAttemptAt: current.nextAttemptAt,
    );
    return true;
  }

  @override
  Future<bool> reschedule({
    required String eventId,
    required String leaseToken,
    required DateTime nextAttemptAt,
    required String errorCode,
    required int maxAttempts,
  }) async {
    final current = _messages[eventId];
    if (current == null || current.state != PluginRevocationOutboxState.leased ||
        current.leaseToken != leaseToken) return false;
    final dead = current.attempts >= maxAttempts;
    _messages[eventId] = PluginRevocationOutboxMessage(
      event: current.event,
      state: dead ? PluginRevocationOutboxState.deadLetter : PluginRevocationOutboxState.pending,
      attempts: current.attempts,
      nextAttemptAt: nextAttemptAt.toUtc(),
      lastErrorCode: errorCode,
    );
    return true;
  }

  Future<List<PluginRevocationOutboxMessage>> snapshot() async =>
      List.unmodifiable(_messages.values);
}

abstract interface class PluginRevocationAuditPublisher {
  /// Publish must be idempotent by [event.eventId] to tolerate the
  /// publish-success/ack-crash window (at-least-once delivery).
  Future<void> publish(PluginRevocationAuditEvent event);
}

final class PluginRevocationOutboxDispatchReport {
  final int claimed;
  final int delivered;
  final int rescheduled;
  final int deadLettered;

  const PluginRevocationOutboxDispatchReport({
    required this.claimed,
    required this.delivered,
    required this.rescheduled,
    required this.deadLettered,
  });
}

/// Dispatches outbox messages with leases and bounded retry scheduling.
/// Delivery is at-least-once; consumers deduplicate using eventId.
class PluginRevocationOutboxDispatcher {
  final PluginRevocationOutboxStore store;
  final PluginRevocationAuditPublisher publisher;
  final String workerId;
  final Duration leaseDuration;
  final int maxAttempts;
  final Duration Function(int attempt) backoff;
  final DateTime Function() clock;

  PluginRevocationOutboxDispatcher({
    required this.store,
    required this.publisher,
    required this.workerId,
    this.leaseDuration = const Duration(seconds: 30),
    this.maxAttempts = 8,
    Duration Function(int attempt)? backoff,
    DateTime Function()? clock,
  })  : backoff = backoff ?? _defaultBackoff,
        clock = clock ?? DateTime.now {
    if (workerId.trim().isEmpty || leaseDuration <= Duration.zero || maxAttempts < 1) {
      throw ArgumentError('Invalid outbox dispatcher configuration.');
    }
  }

  static Duration _defaultBackoff(int attempt) {
    final exponent = attempt.clamp(0, 8);
    return Duration(seconds: 1 << exponent);
  }

  Future<PluginRevocationOutboxDispatchReport> dispatchBatch({int limit = 50}) async {
    final now = clock().toUtc();
    final claimed = await store.claim(
      workerId: workerId,
      now: now,
      leaseDuration: leaseDuration,
      limit: limit,
    );
    var delivered = 0;
    var rescheduled = 0;
    var deadLettered = 0;
    for (final message in claimed) {
      final token = message.leaseToken!;
      try {
        await publisher.publish(message.event);
        if (await store.markDelivered(
          eventId: message.event.eventId,
          leaseToken: token,
          deliveredAt: clock().toUtc(),
        )) {
          delivered++;
        }
      } catch (error) {
        final dead = message.attempts >= maxAttempts;
        final saved = await store.reschedule(
          eventId: message.event.eventId,
          leaseToken: token,
          nextAttemptAt: clock().toUtc().add(backoff(message.attempts)),
          errorCode: error.runtimeType.toString(),
          maxAttempts: maxAttempts,
        );
        if (saved) {
          if (dead) {
            deadLettered++;
          } else {
            rescheduled++;
          }
        }
      }
    }
    return PluginRevocationOutboxDispatchReport(
      claimed: claimed.length,
      delivered: delivered,
      rescheduled: rescheduled,
      deadLettered: deadLettered,
    );
  }
}

import 'plugin_revocation_coordinator.dart';
import 'plugin_revocation_operator_actions.dart';

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
  final String? replayOfEventId;
  final int replayGeneration;

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
    this.replayOfEventId,
    this.replayGeneration = 0,
  }) : assert(replayGeneration >= 0);
}

enum PluginRevocationOutboxState { pending, leased, delivered, deadLetter }

/// Durable outbox envelope with an explicit lease and delivery timestamp.
final class PluginRevocationOutboxMessage {
  final PluginRevocationAuditEvent event;
  final PluginRevocationOutboxState state;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? leaseOwner;
  final String? leaseToken;
  final DateTime? leaseUntil;
  final DateTime? deliveredAt;
  final String? lastErrorCode;

  const PluginRevocationOutboxMessage({
    required this.event,
    required this.state,
    required this.attempts,
    required this.nextAttemptAt,
    this.leaseOwner,
    this.leaseToken,
    this.leaseUntil,
    this.deliveredAt,
    this.lastErrorCode,
  });
}

/// Read-only inspection capability for operational dashboards and support tools.
abstract interface class PluginRevocationOutboxInspectionStore {
  /// Returns a stable snapshot of persisted messages ordered by the adapter.
  /// Implementations must not claim, lease, acknowledge or otherwise mutate rows.
  Future<List<PluginRevocationOutboxMessage>> readAllOutbox();
}

/// Persistence contract for leased outbox delivery.
abstract interface class PluginRevocationOutboxStore {
  Future<List<PluginRevocationOutboxMessage>> claim({
    required String workerId,
    required DateTime now,
    required Duration leaseDuration,
    required int limit,
    required int maxAttempts,
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
    implements TransactionalPluginRevocationStore, PluginRevocationOutboxStore, PluginRevocationOutboxInspectionStore, PluginRevocationDeadLetterReplayStore {
  final Map<String, PluginRevocationExecutionRecord> _executions = {};
  final Map<String, PluginRevocationOutboxMessage> _messages = {};
  final Map<String, PluginRevocationOperatorAction> _operatorActions = {};

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
  Future<void> append(PluginRevocationExecutionRecord record) async {
    _enqueueSync(record);
  }

  @override
  Future<void> completeAndEnqueue(PluginRevocationExecutionRecord record) async {
    if (!_executions.containsKey(record.idempotencyKey)) {
      throw StateError('Cannot complete an unclaimed revocation operation.');
    }
    // No await between these map writes: atomic within this single isolate.
    _executions[record.idempotencyKey] = record;
    _enqueueSync(record);
  }

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
    required int maxAttempts,
  }) async {
    if (workerId.trim().isEmpty ||
        leaseDuration <= Duration.zero ||
        limit < 1 ||
        maxAttempts < 1) {
      throw ArgumentError('workerId, positive leaseDuration, limit and maxAttempts are required.');
    }
    final instant = now.toUtc();

    // An expired final lease is dead-lettered instead of being reclaimed.
    for (final entry in _messages.entries.toList()) {
      final message = entry.value;
      if (message.state == PluginRevocationOutboxState.leased &&
          message.leaseUntil != null &&
          !message.leaseUntil!.isAfter(instant) &&
          message.attempts >= maxAttempts) {
        _messages[entry.key] = PluginRevocationOutboxMessage(
          event: message.event,
          state: PluginRevocationOutboxState.deadLetter,
          attempts: message.attempts,
          nextAttemptAt: message.nextAttemptAt,
          lastErrorCode: 'lease_expired_after_max_attempts',
        );
      }
    }

    final candidates = _messages.values.where((message) {
      if (message.state == PluginRevocationOutboxState.delivered ||
          message.state == PluginRevocationOutboxState.deadLetter ||
          message.attempts >= maxAttempts) {
        return false;
      }
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
    if (current == null ||
        current.state != PluginRevocationOutboxState.leased ||
        current.leaseToken != leaseToken) {
      return false;
    }
    _messages[eventId] = PluginRevocationOutboxMessage(
      event: current.event,
      state: PluginRevocationOutboxState.delivered,
      attempts: current.attempts,
      nextAttemptAt: current.nextAttemptAt,
      deliveredAt: deliveredAt.toUtc(),
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
    if (current == null ||
        current.state != PluginRevocationOutboxState.leased ||
        current.leaseToken != leaseToken) {
      return false;
    }
    final dead = current.attempts >= maxAttempts;
    _messages[eventId] = PluginRevocationOutboxMessage(
      event: current.event,
      state: dead
          ? PluginRevocationOutboxState.deadLetter
          : PluginRevocationOutboxState.pending,
      attempts: current.attempts,
      nextAttemptAt: nextAttemptAt.toUtc(),
      lastErrorCode: errorCode,
    );
    return true;
  }

  @override
  Future<PluginRevocationReplayResult?> replayDeadLetter(
    PluginRevocationReplayRequest request,
  ) async {
    final existingAction = _operatorActions[request.actionId];
    if (existingAction != null) {
      if (existingAction.targetEventId != request.targetEventId ||
          existingAction.actorId != request.actorId ||
          existingAction.scopeId != request.scopeId ||
          existingAction.reason != request.reason ||
          existingAction.approvalReference != request.approvalReference) {
        throw StateError('Operator action ID was already used with different replay details.');
      }
      final replay = _messages[existingAction.replayEventId];
      if (replay == null) throw StateError('Recorded replay event is missing.');
      return PluginRevocationReplayResult(existingAction, replay);
    }
    final source = _messages[request.targetEventId];
    if (source == null || source.state != PluginRevocationOutboxState.deadLetter) {
      return null;
    }
    final generation = _operatorActions.values
        .where((action) => action.targetEventId == request.targetEventId)
        .fold<int>(0, (value, action) => value > action.replayGeneration ? value : action.replayGeneration) + 1;
    final replayEventId = '${source.event.eventId}:replay:$generation';
    final replayKey = '${source.event.idempotencyKey}:replay:$generation';
    if (_messages.containsKey(replayEventId) ||
        _messages.values.any((message) => message.event.idempotencyKey == replayKey)) {
      throw StateError('Replay identity collision.');
    }
    final at = request.occurredAt.toUtc();
    final event = PluginRevocationAuditEvent(
      eventId: replayEventId,
      idempotencyKey: replayKey,
      operationId: source.event.operationId,
      pluginId: source.event.pluginId,
      providerOwnerId: source.event.providerOwnerId,
      action: source.event.action,
      outcome: source.event.outcome,
      occurredAt: at,
      detail: source.event.detail,
      replayOfEventId: source.event.eventId,
      replayGeneration: generation,
    );
    final replay = PluginRevocationOutboxMessage(
      event: event,
      state: PluginRevocationOutboxState.pending,
      attempts: 0,
      nextAttemptAt: at,
    );
    final audit = PluginRevocationOperatorAction(
      actionId: request.actionId,
      actorId: request.actorId,
      scopeId: request.scopeId,
      reason: request.reason,
      approvalReference: request.approvalReference,
      targetEventId: source.event.eventId,
      replayEventId: replayEventId,
      replayGeneration: generation,
      occurredAt: at,
    );
    // No await between writes: reference atomicity within this isolate only.
    _operatorActions[audit.actionId] = audit;
    _messages[replayEventId] = replay;
    return PluginRevocationReplayResult(audit, replay);
  }

  Future<List<PluginRevocationOperatorAction>> readOperatorActions() async =>
      List.unmodifiable(_operatorActions.values.toList()
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt)));

  @override
  Future<List<PluginRevocationOutboxMessage>> readAllOutbox() async =>
      List.unmodifiable(_messages.values.toList()
        ..sort((a, b) => a.event.occurredAt.compareTo(b.event.occurredAt)));

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
    if (workerId.trim().isEmpty ||
        leaseDuration <= Duration.zero ||
        maxAttempts < 1) {
      throw ArgumentError('Invalid outbox dispatcher configuration.');
    }
  }

  static Duration _defaultBackoff(int attempt) {
    final exponent = attempt.clamp(0, 8) as int;
    return Duration(seconds: 1 << exponent);
  }

  Future<PluginRevocationOutboxDispatchReport> dispatchBatch({
    int limit = 50,
  }) async {
    final now = clock().toUtc();
    final claimed = await store.claim(
      workerId: workerId,
      now: now,
      leaseDuration: leaseDuration,
      limit: limit,
      maxAttempts: maxAttempts,
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

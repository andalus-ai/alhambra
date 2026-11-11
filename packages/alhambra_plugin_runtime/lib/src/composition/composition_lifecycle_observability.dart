import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Bounded, storage-independent event fan-out and diagnostic projections.
///
/// Runtime lifecycle callbacks only append to the bounded history and enqueue
/// events for subscribers. Listener callbacks are delivered in microtasks, so
/// slow or throwing observers cannot block or alter composition operations.
final class CompositionLifecycleObservabilityRuntime
    implements CompositionLifecycleObservability {
  final int maxHistoryEvents;
  final int maxSubscribers;
  final int maxPendingEventsPerSubscriber;
  final Map<String, CompositionOwnerState> Function() ownerStatesProvider;

  final List<CompositionLifecycleEvent> _history = [];
  final Map<int, _LifecycleEventSubscription> _subscriptions = {};
  int _nextSubscriptionId = 0;
  int _droppedEventCount = 0;

  CompositionLifecycleObservabilityRuntime({
    required this.ownerStatesProvider,
    this.maxHistoryEvents = 1000,
    this.maxSubscribers = 64,
    this.maxPendingEventsPerSubscriber = 128,
  }) {
    if (maxHistoryEvents < 1) {
      throw ArgumentError.value(maxHistoryEvents, 'maxHistoryEvents');
    }
    if (maxSubscribers < 1) {
      throw ArgumentError.value(maxSubscribers, 'maxSubscribers');
    }
    if (maxPendingEventsPerSubscriber < 1) {
      throw ArgumentError.value(
        maxPendingEventsPerSubscriber,
        'maxPendingEventsPerSubscriber',
      );
    }
  }

  @override
  List<CompositionLifecycleEvent> get lifecycleEvents =>
      List.unmodifiable(_history);

  @override
  int get lifecycleEventSubscriberCount => _subscriptions.length;

  @override
  int get droppedLifecycleEventCount => _droppedEventCount;

  /// Records an event before dispatching it to the current subscribers.
  void record(CompositionLifecycleEvent event) {
    _history.add(event);
    if (_history.length > maxHistoryEvents) {
      _history.removeRange(0, _history.length - maxHistoryEvents);
    }
    for (final subscription in _subscriptions.values.toList(growable: false)) {
      if (!subscription.enqueue(event)) {
        _droppedEventCount++;
      }
    }
  }

  @override
  CompositionLifecycleEventSubscription subscribeLifecycleEvents(
    CompositionLifecycleEventListener listener,
  ) {
    if (_subscriptions.length >= maxSubscribers) {
      throw StateError(
        'Lifecycle event subscriber limit ($maxSubscribers) reached.',
      );
    }
    final id = ++_nextSubscriptionId;
    late final _LifecycleEventSubscription subscription;
    subscription = _LifecycleEventSubscription(
      listener: listener,
      maxPendingEvents: maxPendingEventsPerSubscriber,
      onCancel: () => _subscriptions.remove(id),
    );
    _subscriptions[id] = subscription;
    return subscription;
  }

  @override
  List<CompositionLifecycleEvent> queryLifecycleEvents({
    String? correlationId,
    String? ownerId,
    CompositionLifecycleOperation? operation,
    CompositionLifecycleStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? before,
    int limit = 100,
  }) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('The from bound must not be after the to bound.');
    }
    return List.unmodifiable(_history.where((event) {
      if (correlationId != null && event.correlationId != correlationId) {
        return false;
      }
      if (ownerId != null && !event.ownerIds.contains(ownerId)) return false;
      if (operation != null && event.operation != operation) return false;
      if (status != null && event.status != status) return false;
      if (from != null && event.timestamp.isBefore(from)) return false;
      if (to != null && event.timestamp.isAfter(to)) return false;
      if (before != null && !event.timestamp.isBefore(before)) return false;
      return true;
    }).take(limit).toList(growable: false));
  }

  @override
  List<CompositionLifecycleEvent> timelineForCorrelation(
    String correlationId, {
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) =>
      queryLifecycleEvents(
        correlationId: correlationId,
        from: from,
        to: to,
        limit: limit,
      );

  @override
  CompositionLifecycleOwnerSummary? ownerLifecycleSummary(String ownerId) {
    final events = _history
        .where((event) => event.ownerIds.contains(ownerId))
        .toList(growable: false);
    final failures = events
        .where((event) => event.status == CompositionLifecycleStatus.failed)
        .toList(growable: false);
    if (events.isEmpty && !ownerStatesProvider().containsKey(ownerId)) {
      return null;
    }
    return CompositionLifecycleOwnerSummary(
      ownerId: ownerId,
      state: ownerStatesProvider()[ownerId],
      eventCount: events.length,
      failureCount: failures.length,
      lastEventAt: events.isEmpty ? null : events.last.timestamp,
      lastFailure: failures.isEmpty ? null : failures.last,
    );
  }

  @override
  List<CompositionLifecycleOwnerSummary> get ownerLifecycleSummaries {
    final ownerIds = <String>{
      ...ownerStatesProvider().keys,
      for (final event in _history) ...event.ownerIds,
    }.toList()
      ..sort();
    return List.unmodifiable(ownerIds
        .map(ownerLifecycleSummary)
        .whereType<CompositionLifecycleOwnerSummary>());
  }
}

final class _LifecycleEventSubscription
    implements CompositionLifecycleEventSubscription {
  final CompositionLifecycleEventListener listener;
  final int maxPendingEvents;
  final void Function() onCancel;
  final List<CompositionLifecycleEvent> _pending = [];
  bool _scheduled = false;
  bool _cancelled = false;
  int _droppedEventCount = 0;

  _LifecycleEventSubscription({
    required this.listener,
    required this.maxPendingEvents,
    required this.onCancel,
  });

  @override
  bool get isCancelled => _cancelled;

  @override
  int get droppedEventCount => _droppedEventCount;

  bool enqueue(CompositionLifecycleEvent event) {
    if (_cancelled) return true;
    if (_pending.length >= maxPendingEvents) {
      _droppedEventCount++;
      return false;
    }
    _pending.add(event);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_drain);
    }
    return true;
  }

  void _drain() {
    while (!_cancelled && _pending.isNotEmpty) {
      final event = _pending.removeAt(0);
      try {
        listener(event);
      } catch (_) {
        // An observer is never allowed to affect lifecycle execution.
      }
    }
    _scheduled = false;
    if (!_cancelled && _pending.isNotEmpty) {
      _scheduled = true;
      scheduleMicrotask(_drain);
    }
  }

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _pending.clear();
    onCancel();
  }
}

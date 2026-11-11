import 'composition_contracts.dart';
import 'composition_lifecycle_event_store.dart';

/// Receives lifecycle diagnostics asynchronously from a composition runtime.
///
/// Implementations must return quickly. Each subscriber has an independent
/// bounded queue; when full, the newest event is dropped for that subscriber.
typedef CompositionLifecycleEventListener = void Function(
  CompositionLifecycleEvent event,
);

/// Handle for a bounded lifecycle event subscription.
abstract interface class CompositionLifecycleEventSubscription {
  bool get isCancelled;

  /// Number of events dropped because this subscriber's queue was full.
  int get droppedEventCount;

  void cancel();
}

/// Current owner state and lifecycle activity derived from retained events.
final class CompositionLifecycleOwnerSummary {
  final String ownerId;
  final CompositionOwnerState? state;
  final int eventCount;
  final int failureCount;
  final DateTime? lastEventAt;
  final CompositionLifecycleEvent? lastFailure;

  const CompositionLifecycleOwnerSummary({
    required this.ownerId,
    required this.state,
    required this.eventCount,
    required this.failureCount,
    required this.lastEventAt,
    required this.lastFailure,
  });
}

/// Storage-independent lifecycle observability contract.
///
/// Implementations may expose a bounded in-memory window or combine it with a
/// durable [CompositionLifecycleEventStore]. Time bounds are inclusive;
/// [before] is exclusive. Results are oldest-first.
abstract interface class CompositionLifecycleObservability {
  List<CompositionLifecycleEvent> get lifecycleEvents;

  int get lifecycleEventSubscriberCount;

  int get droppedLifecycleEventCount;

  CompositionLifecycleEventSubscription subscribeLifecycleEvents(
    CompositionLifecycleEventListener listener,
  );

  List<CompositionLifecycleEvent> queryLifecycleEvents({
    String? correlationId,
    String? ownerId,
    CompositionLifecycleOperation? operation,
    CompositionLifecycleStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? before,
    int limit = 100,
  });

  List<CompositionLifecycleEvent> timelineForCorrelation(
    String correlationId, {
    DateTime? from,
    DateTime? to,
    int limit = 100,
  });

  CompositionLifecycleOwnerSummary? ownerLifecycleSummary(String ownerId);

  List<CompositionLifecycleOwnerSummary> get ownerLifecycleSummaries;
}

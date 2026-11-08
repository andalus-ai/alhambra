import 'dart:async';

import 'package:alhambra_core/alhambra_core.dart';

/// Application-level event bus. Decouples producers from consumers.
///
/// Implementations may use in-memory streams, WebSocket, Kafka, etc.
/// Consumers do not know or care which transport carries events.
abstract interface class EventBus {
  /// Publishes [event] to all current subscribers of type [T].
  Future<void> publish<T extends DomainEvent>(T event);

  /// Returns a stream of all events of type [T].
  Stream<T> subscribe<T extends DomainEvent>();

  /// Closes the bus and releases resources.
  Future<void> close();
}

/// Opaque handle to an active event subscription.
abstract interface class EventSubscription {
  /// Cancels this subscription.
  Future<void> cancel();
}

/// Handler contract for a specific domain event type.
abstract interface class EventHandler<T extends DomainEvent> {
  Future<void> handle(T event);
}

// ---------------------------------------------------------------------------
// In-memory implementation for tests and stand-alone use
// ---------------------------------------------------------------------------

/// Lightweight in-memory [EventBus] backed by broadcast [StreamController]s.
final class InMemoryEventBus implements EventBus {
  final Map<Type, dynamic> _controllers = {};
  bool _closed = false;

  @override
  Future<void> publish<T extends DomainEvent>(T event) async {
    if (_closed) throw StateError('EventBus is closed');
    final controller = _controllers[T];
    if (controller != null) {
      (controller as _TypedController<T>).add(event);
    }
  }

  @override
  Stream<T> subscribe<T extends DomainEvent>() {
    if (_closed) throw StateError('EventBus is closed');
    final ctrl = _controllers.putIfAbsent(T, () => _TypedController<T>())
        as _TypedController<T>;
    return ctrl.stream;
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final ctrl in _controllers.values) {
      await (ctrl as _TypedController<DomainEvent>).close();
    }
    _controllers.clear();
  }
}

final class _TypedController<T> {
  final _ctrl = StreamController<T>.broadcast();
  Stream<T> get stream => _ctrl.stream;
  void add(T event) => _ctrl.add(event);
  Future<void> close() => _ctrl.close();
}

import 'dart:async';

/// A simple event bus implementation for inter-plugin communication.
class EventBus {
  final StreamController<Object> _controller =
      StreamController<Object>.broadcast();

  /// Emit an event.
  void emit(Object event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Get a stream of events of type T.
  Stream<T> on<T>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  /// Dispose of the event bus.
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

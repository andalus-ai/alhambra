import 'dart:async';
import 'intelligence_dto.dart';

/// Contract for subscribing to real-time execution events.
abstract interface class ExecutionEventStream {
  Stream<IntelligenceExecutionEventDto> subscribe(String executionId);
}

/// In-memory stream implementation for testing and local usage.
final class InMemoryExecutionEventStream implements ExecutionEventStream {
  final Map<String, StreamController<IntelligenceExecutionEventDto>> _controllers = {};

  StreamController<IntelligenceExecutionEventDto> _ensureController(String id) {
    return _controllers.putIfAbsent(
      id,
      () => StreamController<IntelligenceExecutionEventDto>.broadcast(),
    );
  }

  void emit(IntelligenceExecutionEventDto event) {
    final ctrl = _ensureController(event.executionId);
    if (!ctrl.isClosed) {
      ctrl.add(event);
    }
  }

  @override
  Stream<IntelligenceExecutionEventDto> subscribe(String executionId) {
    return _ensureController(executionId).stream;
  }

  /// Closes all active event streams and clears state.
  Future<void> dispose() async {
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
  }
}

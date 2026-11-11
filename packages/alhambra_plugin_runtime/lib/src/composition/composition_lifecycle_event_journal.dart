import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Bridges synchronous runtime lifecycle callbacks to an asynchronous store.
///
/// Pass an instance as [CompositionLifecycleEventSink]. Events are accepted
/// into a bounded in-memory queue and persisted sequentially, preserving
/// arrival order. The journal never performs storage I/O inside the callback.
///
/// When the queue is full, [add] returns false and increments
/// [rejectedEventCount]. This is an explicit backpressure signal; callers
/// should monitor it and size the queue for their workload. A failed write is
/// retained at the head of the queue and blocks later writes until
/// [retryFailedWrites] is called.
///
/// Call [close] during runtime shutdown to stop accepting events and wait for
/// all accepted events to cross the store's durability boundary.
final class CompositionLifecycleEventJournal {
  final CompositionLifecycleEventStore store;
  final int maxPendingEvents;
  final void Function(Object error, StackTrace stackTrace)? onWriteError;

  final List<CompositionLifecycleEvent> _pending = [];
  Future<void>? _drainFuture;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  int _rejectedEventCount = 0;
  bool _closing = false;
  bool _closed = false;

  CompositionLifecycleEventJournal({
    required this.store,
    this.maxPendingEvents = 512,
    this.onWriteError,
  }) {
    if (maxPendingEvents < 1) {
      throw ArgumentError.value(
        maxPendingEvents,
        'maxPendingEvents',
        'Must be greater than zero.',
      );
    }
  }

  int get pendingCount => _pending.length;
  int get rejectedEventCount => _rejectedEventCount;
  Object? get lastError => _lastError;
  bool get isClosed => _closed;

  /// Enqueues an event without waiting for persistence.
  ///
  /// Returns false when the journal is closing/closed or its queue is full.
  bool add(CompositionLifecycleEvent event) {
    if (_closing || _closed || _pending.length >= maxPendingEvents) {
      _rejectedEventCount++;
      return false;
    }
    _pending.add(event);
    // The callback path must remain synchronous and must not leak an
    // unhandled asynchronous error. The failure is exposed through lastError
    // and can be recovered with retryFailedWrites().
    unawaited(_startDrain().catchError((Object _) {}));
    return true;
  }

  /// Sink-compatible callback for CompositionLifecycleEventSink.
  void call(CompositionLifecycleEvent event) {
    add(event);
  }

  /// Waits until all accepted events have been persisted.
  ///
  /// If a previous write failed, this throws that error and leaves the failed
  /// event queued for an explicit retry.
  Future<void> flush() async {
    _throwIfWriteFailed();
    await _startDrain();
    _throwIfWriteFailed();
  }

  /// Retries the event whose previous append failed, then drains later events.
  Future<void> retryFailedWrites() async {
    _lastError = null;
    _lastStackTrace = null;
    await _startDrain();
    _throwIfWriteFailed();
  }

  /// Stops accepting events and flushes the queue before closing.
  ///
  /// If flushing fails, the journal remains in a closing state; call
  /// [retryFailedWrites] and then [close] again to finish shutdown.
  Future<void> close() async {
    if (_closed) return;
    _closing = true;
    await flush();
    _closed = true;
  }

  Future<void> _startDrain() {
    final active = _drainFuture;
    if (active != null) return active;
    final next = _drainQueue();
    _drainFuture = next;
    return next.whenComplete(() {
      if (identical(_drainFuture, next)) {
        _drainFuture = null;
      }
    });
  }

  Future<void> _drainQueue() async {
    while (_pending.isNotEmpty) {
      try {
        await store.append(_pending.first);
        _pending.removeAt(0);
      } catch (error, stackTrace) {
        _lastError = error;
        _lastStackTrace = stackTrace;
        try {
          onWriteError?.call(error, stackTrace);
        } catch (_) {
          // Error reporting must not replace the storage failure.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  void _throwIfWriteFailed() {
    final error = _lastError;
    final stackTrace = _lastStackTrace;
    if (error != null && stackTrace != null) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

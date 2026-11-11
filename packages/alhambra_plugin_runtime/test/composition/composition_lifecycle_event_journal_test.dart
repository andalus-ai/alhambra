import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  test('persists accepted events sequentially and flush waits for completion', () async {
    final store = _MemoryStore();
    final journal = CompositionLifecycleEventJournal(store: store);
    final first = _event('first');
    final second = _event('second');

    expect(journal.add(first), isTrue);
    expect(journal.add(second), isTrue);
    await journal.flush();

    expect(store.events, [first, second]);
    expect(journal.pendingCount, 0);
  });

  test('retains failed event and retries without losing order', () async {
    final store = _MemoryStore(failNextAppend: true);
    final journal = CompositionLifecycleEventJournal(store: store);
    final first = _event('first');
    final second = _event('second');

    journal.add(first);
    journal.add(second);
    await Future<void>.delayed(Duration.zero);
    expect(journal.lastError, isA<StateError>());
    expect(journal.pendingCount, 2);
    expect(() => journal.flush(), throwsA(isA<StateError>()));

    await journal.retryFailedWrites();
    expect(store.events, [first, second]);
    expect(journal.pendingCount, 0);
    expect(journal.lastError, isNull);
  });

  test('rejects events when bounded queue is full', () async {
    final gate = Completer<void>();
    final store = _MemoryStore(gate: gate);
    final journal = CompositionLifecycleEventJournal(
      store: store,
      maxPendingEvents: 1,
    );

    expect(journal.add(_event('accepted')), isTrue);
    await Future<void>.delayed(Duration.zero);
    // The first event is currently being appended, so fill the one waiting
    // slot with a second event before checking overflow.
    expect(journal.add(_event('queued')), isTrue);
    expect(journal.add(_event('rejected')), isFalse);
    expect(journal.rejectedEventCount, 1);

    gate.complete();
    await journal.flush();
    expect(store.events.map((event) => event.correlationId),
        ['accepted', 'queued']);
  });

  test('close flushes and rejects subsequent events', () async {
    final store = _MemoryStore();
    final journal = CompositionLifecycleEventJournal(store: store);
    final event = _event('shutdown');

    journal.add(event);
    await journal.close();

    expect(journal.isClosed, isTrue);
    expect(store.events, [event]);
    expect(journal.add(_event('late')), isFalse);
  });
}

CompositionLifecycleEvent _event(String id) => CompositionLifecycleEvent(
      correlationId: id,
      operation: CompositionLifecycleOperation.prepare,
      status: CompositionLifecycleStatus.succeeded,
      timestamp: DateTime.utc(2026, 1, 1),
      nodeIds: const [],
      ownerIds: const [],
    );

class _MemoryStore implements CompositionLifecycleEventStore {
  final List<CompositionLifecycleEvent> events = [];
  bool failNextAppend;
  final Completer<void>? gate;

  _MemoryStore({this.failNextAppend = false, this.gate});

  @override
  Future<void> append(CompositionLifecycleEvent event) async {
    if (gate != null && !gate!.isCompleted) await gate!.future;
    if (failNextAppend) {
      failNextAppend = false;
      throw StateError('temporary storage failure');
    }
    events.add(event);
  }

  @override
  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  ) async => List.unmodifiable(events);
}

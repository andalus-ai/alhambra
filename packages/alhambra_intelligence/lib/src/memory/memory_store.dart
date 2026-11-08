import 'memory_query.dart';
import 'memory_record.dart';

/// Contract for persisting and reading episodic/semantic memory records.
abstract interface class MemoryStore {
  Future<void> save(MemoryRecord record);

  Future<MemoryRecord?> get(String id);

  Future<List<MemoryRecord>> search(MemoryQuery query);

  Future<void> clear();
}

/// In-memory implementation of [MemoryStore].
final class InMemoryMemoryStore implements MemoryStore {
  final Map<String, MemoryRecord> _store = {};

  InMemoryMemoryStore([List<MemoryRecord>? initial]) {
    if (initial != null) {
      for (final r in initial) {
        _store[r.id] = r;
      }
    }
  }

  @override
  Future<void> save(MemoryRecord record) async {
    _store[record.id] = record;
  }

  @override
  Future<MemoryRecord?> get(String id) async => _store[id];

  @override
  Future<List<MemoryRecord>> search(MemoryQuery query) async {
    final lower = query.text.toLowerCase();
    return _store.values
        .where((r) => r.content.toLowerCase().contains(lower))
        .take(query.limit)
        .toList();
  }

  @override
  Future<void> clear() async => _store.clear();
}

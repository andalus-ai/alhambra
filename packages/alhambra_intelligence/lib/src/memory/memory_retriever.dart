import 'memory_query.dart';
import 'memory_record.dart';
import 'memory_store.dart';

/// Contract for retrieving relevant past memory context during workflow execution.
abstract interface class MemoryRetriever {
  Future<List<MemoryRecord>> retrieve(MemoryQuery query);
}

/// Default implementation delegating to [MemoryStore].
final class DefaultMemoryRetriever implements MemoryRetriever {
  final MemoryStore store;

  const DefaultMemoryRetriever(this.store);

  @override
  Future<List<MemoryRecord>> retrieve(MemoryQuery query) async {
    return store.search(query);
  }
}

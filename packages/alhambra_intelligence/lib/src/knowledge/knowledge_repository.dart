import 'knowledge_item.dart';
import 'knowledge_query.dart';

/// Repository interface for saving, fetching, and querying knowledge items.
abstract interface class KnowledgeRepository {
  Future<KnowledgeItem?> get(String id);

  Future<List<KnowledgeItem>> search(KnowledgeQuery query);

  Future<void> save(KnowledgeItem item);

  Future<void> delete(String id);
}

/// In-memory implementation of [KnowledgeRepository] for testing and local usage.
final class InMemoryKnowledgeRepository implements KnowledgeRepository {
  final Map<String, KnowledgeItem> _items = {};

  InMemoryKnowledgeRepository([List<KnowledgeItem>? initial]) {
    if (initial != null) {
      for (final item in initial) {
        _items[item.id] = item;
      }
    }
  }

  @override
  Future<KnowledgeItem?> get(String id) async => _items[id];

  @override
  Future<List<KnowledgeItem>> search(KnowledgeQuery query) async {
    final lower = query.text.toLowerCase();
    return _items.values
        .where((item) =>
            item.title.toLowerCase().contains(lower) ||
            item.content.toLowerCase().contains(lower))
        .take(query.limit)
        .toList();
  }

  @override
  Future<void> save(KnowledgeItem item) async {
    _items[item.id] = item;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
}

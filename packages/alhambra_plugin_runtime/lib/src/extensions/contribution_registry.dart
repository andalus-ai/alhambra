import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class ContributionRegistry<T extends OwnedContribution>
    implements OwnerCleanup {
  final Map<String, T> _items = {};
  final Map<String, Set<String>> _idsByOwner = {};

  void register(T item) {
    if (_items.containsKey(item.id)) {
      unregister(item.id);
    }

    _items[item.id] = item;
    _idsByOwner.putIfAbsent(item.ownerId, () => <String>{}).add(item.id);
  }

  T? get(String id) => _items[id];

  bool contains(String id) => _items.containsKey(id);

  List<T> get all => List.unmodifiable(_items.values.toList());

  List<T> getAll() => all;

  List<T> getAllForOwner(String ownerId) {
    final ids = _idsByOwner[ownerId];
    if (ids == null) return const [];
    return ids.map((id) => _items[id]).whereType<T>().toList(growable: false);
  }

  void unregister(String id) {
    final item = _items.remove(id);
    if (item == null) return;

    final ownerIds = _idsByOwner[item.ownerId];
    ownerIds?.remove(id);
    if (ownerIds != null && ownerIds.isEmpty) {
      _idsByOwner.remove(item.ownerId);
    }
  }

  @override
  void unregisterAllForOwner(String ownerId) {
    final ids = _idsByOwner.remove(ownerId);
    if (ids == null) return;

    for (final id in ids) {
      _items.remove(id);
    }
  }

  void clear() {
    _items.clear();
    _idsByOwner.clear();
  }
}

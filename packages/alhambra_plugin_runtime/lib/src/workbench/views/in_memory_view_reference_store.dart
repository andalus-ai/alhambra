import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class InMemoryViewReferenceStore implements ViewReferenceStore {
  final Map<String, PersistedViewReference> _store = {};

  @override
  PersistedViewReference? get(String viewId) => _store[viewId];

  @override
  void remember(PersistedViewReference reference) {
    _store[reference.viewId] = reference;
  }

  @override
  void forget(String viewId) {
    _store.remove(viewId);
  }

  @override
  Iterable<PersistedViewReference> get all => _store.values;
}

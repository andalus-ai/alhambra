import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class ServiceRegistry implements OwnerCleanup {
  final Map<Type, dynamic> _services = {};
  final Map<String, Set<Type>> _servicesByOwner = {};

  void register<T>(T service, {required String ownerId}) {
    _services[T] = service;
    _servicesByOwner.putIfAbsent(ownerId, () => <Type>{}).add(T);
  }

  T? get<T>() {
    final s = _services[T];
    if (s is T) return s;
    return null;
  }

  bool has<T>() => _services.containsKey(T);

  @override
  void unregisterAllForOwner(String ownerId) {
    final types = _servicesByOwner.remove(ownerId);
    if (types == null) return;
    for (final type in types) {
      _services.remove(type);
    }
  }

  void clear() {
    _services.clear();
    _servicesByOwner.clear();
  }
}

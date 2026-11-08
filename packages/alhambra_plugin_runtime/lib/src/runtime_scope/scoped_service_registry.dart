import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

abstract interface class ScopedServiceRegistry implements ServiceScope {
  void register<T>(ServiceKey<T> key, T service, {ServiceLifetime lifetime});
  void unregister<T>(ServiceKey<T> key);
}

class InMemoryScopedServiceRegistry implements ScopedServiceRegistry {
  final ServiceScope? parent;
  final Map<ServiceKey<dynamic>, dynamic> _services = {};

  InMemoryScopedServiceRegistry({this.parent});

  @override
  void register<T>(
    ServiceKey<T> key,
    T service, {
    ServiceLifetime lifetime = ServiceLifetime.application,
  }) {
    _services[key] = service;
  }

  @override
  void unregister<T>(ServiceKey<T> key) {
    _services.remove(key);
  }

  @override
  T? read<T>(ServiceKey<T> key) {
    if (_services.containsKey(key)) {
      return _services[key] as T?;
    }
    return parent?.read<T>(key);
  }

  @override
  T readRequired<T>(ServiceKey<T> key) {
    final s = read<T>(key);
    if (s == null) {
      throw StateError(
        'Required service "$key" not found in current scope hierarchy',
      );
    }
    return s;
  }

  void clear() {
    _services.clear();
  }
}

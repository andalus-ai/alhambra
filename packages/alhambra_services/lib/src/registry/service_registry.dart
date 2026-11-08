import 'service_descriptor.dart';

/// Contract for dynamically registering, resolving, and discovering services.
abstract interface class ServiceRegistry {
  /// Registers or updates a service descriptor.
  Future<void> register(ServiceDescriptor service);

  /// Retrieves a service descriptor by ID.
  Future<ServiceDescriptor?> get(String serviceId);

  /// Lists all registered service descriptors.
  Future<List<ServiceDescriptor>> list();
}

/// In-memory implementation of [ServiceRegistry].
final class InMemoryServiceRegistry implements ServiceRegistry {
  final Map<String, ServiceDescriptor> _services = {};

  @override
  Future<void> register(ServiceDescriptor service) async {
    _services[service.id] = service;
  }

  @override
  Future<ServiceDescriptor?> get(String serviceId) async => _services[serviceId];

  @override
  Future<List<ServiceDescriptor>> list() async => _services.values.toList();
}

/// Metadata descriptor for a service registered in the Alhambra platform.
final class ServiceDescriptor {
  final String id;
  final String name;
  final String version;
  final String status;

  const ServiceDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
  });

  @override
  String toString() => 'ServiceDescriptor($id: $name v$version [$status])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceDescriptor &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Defines Alhambra API versioning policy and constants.
final class ApiVersion {
  /// The canonical specification version.
  static const String current = '2026-01';

  /// Default REST route prefix.
  static const String defaultPrefix = '/api/v1';

  final String version;

  const ApiVersion(this.version);

  @override
  String toString() => version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiVersion &&
          runtimeType == other.runtimeType &&
          version == other.version;

  @override
  int get hashCode => version.hashCode;
}

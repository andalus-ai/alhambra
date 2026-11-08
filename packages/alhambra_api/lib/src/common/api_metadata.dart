/// Metadata accompanying an API response envelope.
final class ApiMetadata {
  final String requestId;
  final DateTime timestamp;
  final String version;

  const ApiMetadata({
    required this.requestId,
    required this.timestamp,
    this.version = 'v1',
  });

  @override
  String toString() => 'ApiMetadata($requestId, $version at $timestamp)';
}

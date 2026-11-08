/// Server-Sent Event payload.
final class SseEvent {
  final String? id;
  final String? event;
  final String data;

  const SseEvent({
    this.id,
    this.event,
    required this.data,
  });

  @override
  String toString() =>
      'SseEvent(event: $event, id: $id, data: ${data.length > 80 ? '${data.substring(0, 80)}…' : data})';
}

/// Contract for SSE-based streaming from server push endpoints.
abstract interface class SseClient {
  /// Opens an SSE connection to [url] and returns its event stream.
  Stream<SseEvent> connect(String url, {Map<String, String>? headers});
}

/// Sealed event hierarchy for WebSocket connections.
sealed class WebSocketEvent {
  const WebSocketEvent();
}

/// Emitted when a WebSocket connection is established.
final class WebSocketConnected extends WebSocketEvent {
  const WebSocketConnected();
}

/// Emitted when a data frame is received.
final class WebSocketMessage extends WebSocketEvent {
  final Object data;
  const WebSocketMessage(this.data);
}

/// Emitted when the WebSocket connection is closed.
final class WebSocketDisconnected extends WebSocketEvent {
  final int? code;
  final String? reason;
  const WebSocketDisconnected({this.code, this.reason});
}

/// Emitted when a WebSocket error occurs.
final class WebSocketError extends WebSocketEvent {
  final Object error;
  const WebSocketError(this.error);
}

/// Contract for generic WebSocket communication.
abstract interface class WebSocketClient {
  /// Stream of typed events from the socket.
  Stream<WebSocketEvent> get events;

  /// Connects to [url].
  Future<void> connect(String url);

  /// Sends a [message] over the socket.
  Future<void> send(Object message);

  /// Closes the connection.
  Future<void> close();
}

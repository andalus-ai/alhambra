
/// Represents an event that is fired when a file is opened.
class FileOpenedEvent {
  /// The path to the file.
  final String path;
  /// The language of the file.
  final String? language;

  /// Creates a new [FileOpenedEvent] instance.
  const FileOpenedEvent({required this.path, this.language});
}

/// Represents an event that is fired when a workspace is changed.
class WorkspaceChangedEvent {
  /// The path to the workspace.
  final String workspacePath;
  /// The name of the workspace.
  final String workspaceName;

  /// Creates a new [WorkspaceChangedEvent] instance.
  const WorkspaceChangedEvent({
    required this.workspacePath,
    required this.workspaceName,
  });
}

/// Represents an event that is fired when an agent session is created.
class AgentSessionCreatedEvent {
  /// The ID of the session.
  final String sessionId;
  /// The title of the session.
  final String? title;

  /// Creates a new [AgentSessionCreatedEvent] instance.
  const AgentSessionCreatedEvent({
    required this.sessionId,
    this.title,
  });
}

/// Represents an event that is fired when a backend status is changed.
class BackendStatusChangedEvent {
  /// The name of the server.
  final String serverName;
  /// The status of the server.
  final String status;
  /// The port of the server.
  final int? port;

  /// Creates a new [BackendStatusChangedEvent] instance.
  const BackendStatusChangedEvent({
    required this.serverName,
    required this.status,
    this.port,
  });
}

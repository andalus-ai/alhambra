import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

final class WindowUiContext {
  final WindowId windowId;
  final ApplicationId applicationId;

  const WindowUiContext({
    required this.windowId,
    this.applicationId = const ApplicationId(),
  });
}

final class WorkbenchUiContext {
  final WorkbenchSessionId sessionId;
  final WindowId windowId;
  final WorkspaceId workspaceId;

  const WorkbenchUiContext({
    required this.sessionId,
    required this.windowId,
    required this.workspaceId,
  });
}

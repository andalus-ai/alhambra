/// Sealed hierarchy of declarative UI actions.
sealed class UiAction {
  const UiAction();
}

/// Navigate to an application or external route.
final class NavigateAction extends UiAction {
  final String route;
  const NavigateAction(this.route);
}

/// Submit a form or payload to an application endpoint.
final class SubmitAction extends UiAction {
  final String target;
  final Map<String, Object?> payload;
  const SubmitAction({required this.target, this.payload = const {}});
}

/// Invoke a named tool or command.
final class InvokeAction extends UiAction {
  final String command;
  final Map<String, Object?> parameters;
  const InvokeAction({required this.command, this.parameters = const {}});
}

/// Refresh the current view / surface.
final class RefreshAction extends UiAction {
  const RefreshAction();
}

/// Request governance approval.
final class ApproveAction extends UiAction {
  final String resourceId;
  const ApproveAction(this.resourceId);
}

/// Request governance rejection.
final class RejectAction extends UiAction {
  final String resourceId;
  final String? reason;
  const RejectAction(this.resourceId, {this.reason});
}

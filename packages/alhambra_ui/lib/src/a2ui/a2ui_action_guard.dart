import 'ui_action.dart';
import 'ui_surface.dart';

/// Safety contract for A2UI action dispatch.
///
/// The critical P14 boundary:
/// ```
/// Agent decides WHAT → A2UI describes HOW → renderer decides HOW IT LOOKS
/// ```
/// But: permissions, data access, and governance are OUTSIDE agent-generated UI.
///
/// [A2UiActionGuard] enforces this by evaluating each [UiAction] before dispatch,
/// blocking unauthorized or out-of-scope operations.
abstract interface class A2UiActionGuard {
  /// Returns `true` if [action] is permitted in the current surface context.
  bool permits(UiSurface surface, UiAction action);

  /// Returns a human-readable reason when [permits] returns `false`.
  String? denyReason(UiSurface surface, UiAction action);
}

/// Default guard that permits all navigate/refresh/approve/reject actions
/// but restricts [InvokeAction] to an allowlist of safe command names.
///
/// This prevents agents from invoking arbitrary application commands.
final class DefaultA2UiActionGuard implements A2UiActionGuard {
  /// Commands agents are allowed to invoke by default.
  static const _defaultAllowedCommands = {
    'refresh',
    'open_artifact',
    'view_evidence',
    'view_provenance',
    'request_review',
  };

  final Set<String> allowedCommands;

  const DefaultA2UiActionGuard({
    this.allowedCommands = _defaultAllowedCommands,
  });

  @override
  bool permits(UiSurface surface, UiAction action) => switch (action) {
        NavigateAction() => true,
        RefreshAction() => true,
        ApproveAction() => true,
        RejectAction() => true,
        SubmitAction(:final target) => !target.startsWith('_internal/'),
        InvokeAction(:final command) => allowedCommands.contains(command),
      };

  @override
  String? denyReason(UiSurface surface, UiAction action) {
    if (permits(surface, action)) return null;
    return switch (action) {
      InvokeAction(:final command) =>
        'Command "$command" is not permitted in agent-generated surfaces',
      SubmitAction() => 'Internal submit targets are not accessible from A2UI',
      _ => 'Action not permitted',
    };
  }
}

/// A guard that blocks ALL actions — useful for read-only surface previews.
final class ReadOnlyA2UiActionGuard implements A2UiActionGuard {
  const ReadOnlyA2UiActionGuard();

  @override
  bool permits(UiSurface surface, UiAction action) => false;

  @override
  String? denyReason(UiSurface surface, UiAction action) =>
      'This surface is read-only';
}

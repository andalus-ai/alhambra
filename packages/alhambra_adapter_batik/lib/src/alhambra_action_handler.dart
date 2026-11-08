import 'package:batik/batik.dart' as batik;
import 'package:flutter/widgets.dart';
import 'package:alhambra_ui/alhambra_ui.dart' as a2ui;

/// Batik [batik.ActionHandler] implementation that routes Batik UIActions
/// to Alhambra's [a2ui.UiAction] callback.
///
/// Wire this into Batik's [batik.ActionDispatcher] to allow Batik-rendered
/// surfaces to interact with Alhambra navigation, governance approval, etc.
///
/// ```dart
/// final dispatcher = batik.ActionDispatcher(
///   handler: AlhambraActionHandler(
///     onAction: (action) => myRouter.handleA2UiAction(action),
///   ),
///   variableStore: batik.VariableStore(),
/// );
/// ```
class AlhambraActionHandler implements batik.ActionHandler {
  final void Function(a2ui.UiAction action) onAction;
  final a2ui.A2UiActionGuard? guard;
  final a2ui.UiSurface? surface;

  const AlhambraActionHandler({
    required this.onAction,
    this.guard,
    this.surface,
  });

  @override
  Future<void> handle(
    BuildContext context,
    batik.UIAction action,
    Map<String, dynamic> variables,
  ) async {
    final a2uiAction = _toA2UiAction(action);

    // Apply Alhambra's action guard if provided.
    final g = guard;
    final s = surface;
    if (g != null && s != null && !g.permits(s, a2uiAction)) {
      debugPrint(
        '[AlhambraActionHandler] Blocked: ${g.denyReason(s, a2uiAction)}',
      );
      return;
    }

    onAction(a2uiAction);
  }

  static a2ui.UiAction _toA2UiAction(batik.UIAction action) =>
      switch (action.type) {
        'navigate' => a2ui.NavigateAction(
            action.payload['route'] as String? ?? '/'),
        'submitForm' => a2ui.SubmitAction(
            target: action.payload['target'] as String? ?? '',
            payload: Map<String, Object?>.from(action.payload)..remove('target'),
          ),
        'custom' => () {
            final cmd = action.payload['command'] as String?;
            if (cmd == null || cmd == 'refresh') return const a2ui.RefreshAction();
            if (cmd == 'approve') {
              return a2ui.ApproveAction(
                  action.payload['resourceId'] as String? ?? '');
            }
            if (cmd == 'reject') {
              return a2ui.RejectAction(
                action.payload['resourceId'] as String? ?? '',
                reason: action.payload['reason'] as String?,
              );
            }
            return a2ui.InvokeAction(
              command: cmd,
              parameters: Map<String, Object?>.from(action.payload)
                ..remove('command'),
            );
          }(),
        _ => const a2ui.RefreshAction(),
      };
}

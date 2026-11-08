/// Action availability model for the Alhambra UI.
///
/// An action can be:
/// - **visible + enabled** → normal active button
/// - **visible + disabled** → shown greyed with [disabledReason] tooltip
/// - **hidden** → not rendered at all
///
/// This avoids simply hiding everything — sometimes showing
/// "Publish — waiting for approval" is better UX than hiding the button.
final class UiActionState {
  /// Whether to render the action at all.
  final bool visible;

  /// Whether the action can be triggered.
  final bool enabled;

  /// Human-readable explanation shown when [enabled] is false.
  final String? disabledReason;

  const UiActionState({
    required this.visible,
    required this.enabled,
    this.disabledReason,
  });

  /// Convenient factory for a fully active action.
  const UiActionState.active()
      : visible = true,
        enabled = true,
        disabledReason = null;

  /// Convenient factory for a visible but disabled action.
  const UiActionState.disabled(String reason)
      : visible = true,
        enabled = false,
        disabledReason = reason;

  /// Convenient factory for a hidden action.
  const UiActionState.hidden()
      : visible = false,
        enabled = false,
        disabledReason = null;

  @override
  String toString() =>
      'UiActionState(visible: $visible, enabled: $enabled, reason: $disabledReason)';
}

/// A named action entry with its availability state.
final class UiActionEntry {
  /// Stable identifier (e.g., `'submit_review'`).
  final String id;

  /// Display label.
  final String label;

  /// Optional icon name or asset path.
  final String? icon;

  /// Current availability.
  final UiActionState state;

  /// The callback invoked when the user triggers the action.
  final void Function()? onPressed;

  const UiActionEntry({
    required this.id,
    required this.label,
    required this.state,
    this.icon,
    this.onPressed,
  });
}

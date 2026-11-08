import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/module_manager_provider.dart';
import 'generic_workbench_layout_view.dart';

/// Dynamic host that renders the active workspace mode layout.
///
/// Resolution order:
/// 1. The active mode's [viewBuilder] — contributed by a domain plugin pack
///    or platform config (e.g. a coding IDE, a workflow canvas, a chat UI).
/// 2. An optional [layoutFactory] provided directly to this widget — useful
///    when a platform adopter wants to substitute the default workbench with
///    a custom one without creating a full [WorkspaceMode].
/// 3. The default neutral [GenericWorkbenchLayoutView] that adapts to small,
///    medium, and large screens automatically.
///
/// ### Extension example (platform adopter)
///
/// Substitute individual slots without replacing the whole layout:
///
/// ```dart
/// WorkspaceViewHost(
///   layoutFactory: (context) => GenericWorkbenchLayoutView(
///     activityBarBuilder: (ctx) => MyBrandedActivityBar(),
///     sidebarBuilder:     (ctx) => MyProjectExplorer(),
///   ),
/// )
/// ```
///
/// Or supply a completely custom layout for a specific workspace mode:
///
/// ```dart
/// final myMode = WorkspaceMode(
///   id: 'my.canvas',
///   label: 'Canvas',
///   viewBuilder: (ctx) => MyFullscreenCanvasView(),
/// );
/// ```
class WorkspaceViewHost extends ConsumerWidget {
  /// Optional factory that produces the root layout widget.
  ///
  /// When non-null this takes precedence over the default
  /// [GenericWorkbenchLayoutView], but is still overridden by the active
  /// workspace mode's own [viewBuilder].
  final WidgetBuilder? layoutFactory;

  const WorkspaceViewHost({
    super.key,
    this.layoutFactory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(activeWorkspaceModeProvider);

    // 1. Mode-specific view builder (highest priority)
    if (activeMode.viewBuilder != null) {
      return activeMode.viewBuilder!(context);
    }

    // 2. Custom layout factory provided by the platform adopter
    if (layoutFactory != null) {
      return layoutFactory!(context);
    }

    // 3. Default responsive multi-pane workbench layout
    return const GenericWorkbenchLayoutView();
  }
}

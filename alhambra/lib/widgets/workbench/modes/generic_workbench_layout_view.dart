import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import '../../platform_breakpoints.dart';
import '../../../layouts/layout_plugin_host.dart';
import '../../../layouts/workbench_layout.dart';

/// Neutral, multi-pane dockable Workbench layout.
///
/// This widget is a thin shim over the [WorkbenchLayout] plugin that can be
/// used anywhere in the widget tree without going through the full
/// [LayoutPluginHost] / Riverpod provider chain.
///
/// Preferred usage: use [LayoutPluginHost] at the screen root for full plugin
/// support. Use [GenericWorkbenchLayoutView] only for embedded sub-layouts,
/// widget tests, or preview contexts.
///
/// ### Extension via slot overrides
///
/// ```dart
/// GenericWorkbenchLayoutView(
///   slots: LayoutSlotConfig({
///     LayoutSlot.sidebar: (ctx) => MyProjectExplorer(),
///     LayoutSlot.activityBar: (ctx) => MyBrandedBar(),
///   }),
/// )
/// ```
class GenericWorkbenchLayoutView extends ConsumerWidget {
  /// Per-slot widget-builder overrides.
  final LayoutSlotConfig slots;

  /// The [AppKind] hint passed to the underlying [WorkbenchLayout].
  final AppKind appKind;

  const GenericWorkbenchLayoutView({
    super.key,
    this.slots = const LayoutSlotConfig(),
    this.appKind = AppKind.ide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenClass =
            PlatformBreakpoints.classFor(constraints.maxWidth);

        return PlatformScreenClass(
          screenClass: screenClass,
          child: const WorkbenchLayout().build(
            context,
            screenClass: screenClass,
            appKind: appKind,
            slots: slots,
          ),
        );
      },
    );
  }
}

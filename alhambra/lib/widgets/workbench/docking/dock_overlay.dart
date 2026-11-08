import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';
import 'dock_drag_data.dart';
import 'dock_drag_session.dart';
import 'dock_drop_executor.dart';
import 'dock_target.dart';
import 'dock_target_registry.dart';
import 'dock_target_resolver.dart';
import 'drop_intent.dart';

final dockTargetRegistryProvider = Provider<DockTargetRegistry>((ref) {
  return InMemoryDockTargetRegistry();
});

class DockDragSessionNotifier extends Notifier<DockDragSession?> {
  @override
  DockDragSession? build() => null;

  void begin(DockDragData data, Offset position) {
    final registry = ref.read(dockTargetRegistryProvider);
    const resolver = DockTargetResolver();
    final intent = resolver.resolve(
      data: data,
      position: position,
      targets: registry.targets,
    );
    state = DockDragSession(
      data: data,
      globalPosition: position,
      intent: intent,
    );
  }

  void update(Offset position) {
    final current = state;
    if (current == null) return;
    final registry = ref.read(dockTargetRegistryProvider);
    const resolver = DockTargetResolver();
    final intent = resolver.resolve(
      data: current.data,
      position: position,
      targets: registry.targets,
    );
    state = DockDragSession(
      data: current.data,
      globalPosition: position,
      intent: intent,
    );
  }

  void drop() {
    final current = state;
    if (current == null) return;
    state = null;
    if (current.intent is! NoDropIntent) {
      final executor = DockDropExecutor(ref.read(workbenchControllerProvider));
      executor.execute(current.data, current.intent);
    }
  }

  void cancel() {
    state = null;
  }
}

final dockDragSessionProvider =
    NotifierProvider<DockDragSessionNotifier, DockDragSession?>(
  () => DockDragSessionNotifier(),
);

class DockOverlay extends ConsumerWidget {
  final Widget child;

  const DockOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(dockDragSessionProvider);
    final registry = ref.watch(dockTargetRegistryProvider);

    return Stack(
      children: [
        child,
        if (session != null && session.intent is! NoDropIntent)
          Positioned.fill(
            child: IgnorePointer(
              child: _buildDropIndicator(session, registry),
            ),
          ),
      ],
    );
  }

  Widget _buildDropIndicator(
    DockDragSession session,
    DockTargetRegistry registry,
  ) {
    final intent = session.intent;
    String? targetGroupId;

    if (intent is ReorderDropIntent) targetGroupId = intent.targetGroupId;
    if (intent is MoveToGroupDropIntent) targetGroupId = intent.targetGroupId;
    if (intent is SplitDropIntent) targetGroupId = intent.targetGroupId;

    if (targetGroupId == null) return const SizedBox.shrink();

    final target = registry.get(targetGroupId);
    if (target == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: _DockDropPainter(
        intent: intent,
        target: target,
      ),
    );
  }
}

class _DockDropPainter extends CustomPainter {
  final DropIntent intent;
  final DockTarget target;

  _DockDropPainter({
    required this.intent,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = target.bounds;
    final paintFill = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Rect? highlightRect;

    switch (intent) {
      case NoDropIntent():
        return;

      case MoveToGroupDropIntent():
        highlightRect = bounds;

      case SplitDropIntent(side: final side):
        highlightRect = switch (side) {
          DockSide.left => Rect.fromLTWH(
              bounds.left,
              bounds.top,
              bounds.width * 0.5,
              bounds.height,
            ),
          DockSide.right => Rect.fromLTWH(
              bounds.left + bounds.width * 0.5,
              bounds.top,
              bounds.width * 0.5,
              bounds.height,
            ),
          DockSide.top => Rect.fromLTWH(
              bounds.left,
              bounds.top,
              bounds.width,
              bounds.height * 0.5,
            ),
          DockSide.bottom => Rect.fromLTWH(
              bounds.left,
              bounds.top + bounds.height * 0.5,
              bounds.width,
              bounds.height * 0.5,
            ),
        };

      case ReorderDropIntent():
        final tabStripBounds = target.tabStripBounds;
        final linePaint = Paint()
          ..color = AppTheme.accent
          ..strokeWidth = 3.0;
        canvas.drawLine(
          Offset(bounds.left, tabStripBounds.top),
          Offset(bounds.left, tabStripBounds.bottom),
          linePaint,
        );
        return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
      paintFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
      paintBorder,
    );
  }

  @override
  bool shouldRepaint(covariant _DockDropPainter oldDelegate) => true;
}

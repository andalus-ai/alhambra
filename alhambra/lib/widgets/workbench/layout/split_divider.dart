import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import '../../../providers/module_manager_provider.dart';
import '../../../theme/app_colors.dart';

class SplitDivider extends ConsumerStatefulWidget {
  final SplitNode node;
  final double totalSize;

  const SplitDivider({
    super.key,
    required this.node,
    required this.totalSize,
  });

  @override
  ConsumerState<SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends ConsumerState<SplitDivider> {
  bool _isHovered = false;
  bool _isDragging = false;
  double? _startRatio;
  double? _startPosition;

  Axis get _dragAxis => widget.node.direction == SplitDirection.horizontal
      ? Axis.horizontal
      : Axis.vertical;

  void _handleDragStart(DragStartDetails details) {
    _startRatio = widget.node.ratio;
    _startPosition = _dragAxis == Axis.horizontal
        ? details.globalPosition.dx
        : details.globalPosition.dy;
    setState(() => _isDragging = true);

    ref.read(workbenchControllerProvider).beginSplitResize(widget.node.id);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final startRatio = _startRatio;
    final startPos = _startPosition;
    if (startRatio == null || startPos == null || widget.totalSize <= 0) return;

    final currentPos = _dragAxis == Axis.horizontal
        ? details.globalPosition.dx
        : details.globalPosition.dy;

    final delta = currentPos - startPos;
    final nextRatio =
        (startRatio + (delta / widget.totalSize)).clamp(0.05, 0.95);

    ref
        .read(workbenchControllerProvider)
        .resizeSplit(widget.node.id, nextRatio);
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _startRatio = null;
    _startPosition = null;

    ref.read(workbenchControllerProvider).endSplitResize(widget.node.id);
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = _dragAxis == Axis.horizontal;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          ref
              .read(workbenchControllerProvider)
              .resizeSplit(widget.node.id, 0.5);
        },
        onHorizontalDragStart: isHorizontal ? _handleDragStart : null,
        onHorizontalDragUpdate: isHorizontal ? _handleDragUpdate : null,
        onHorizontalDragEnd: isHorizontal ? _handleDragEnd : null,
        onVerticalDragStart: !isHorizontal ? _handleDragStart : null,
        onVerticalDragUpdate: !isHorizontal ? _handleDragUpdate : null,
        onVerticalDragEnd: !isHorizontal ? _handleDragEnd : null,
        child: Container(
          width: isHorizontal ? 4 : double.infinity,
          height: isHorizontal ? double.infinity : 4,
          color: (_isHovered || _isDragging)
              ? AppTheme.accent.withValues(alpha: 0.7)
              : AppTheme.border,
        ),
      ),
    );
  }
}

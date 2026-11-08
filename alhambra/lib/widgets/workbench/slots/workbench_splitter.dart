import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

enum SplitterAxis {
  horizontal, // Left-Right resize
  vertical,   // Top-Bottom resize
}

class WorkbenchSplitter extends StatefulWidget {
  final SplitterAxis axis;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDoubleClick;

  const WorkbenchSplitter({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDoubleClick,
  });

  @override
  State<WorkbenchSplitter> createState() => _WorkbenchSplitterState();
}

class _WorkbenchSplitterState extends State<WorkbenchSplitter> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == SplitterAxis.horizontal;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleClick,
        onHorizontalDragStart: isHorizontal ? (_) => setState(() => _isDragging = true) : null,
        onHorizontalDragEnd: isHorizontal ? (_) => setState(() => _isDragging = false) : null,
        onHorizontalDragUpdate: isHorizontal
            ? (details) => widget.onDrag(details.delta.dx)
            : null,
        onVerticalDragStart: !isHorizontal ? (_) => setState(() => _isDragging = true) : null,
        onVerticalDragEnd: !isHorizontal ? (_) => setState(() => _isDragging = false) : null,
        onVerticalDragUpdate: !isHorizontal
            ? (details) => widget.onDrag(details.delta.dy)
            : null,
        child: Container(
          width: isHorizontal ? 4 : double.infinity,
          height: isHorizontal ? double.infinity : 4,
          color: (_isHovered || _isDragging)
              ? AppTheme.accent.withValues(alpha: 0.6)
              : AppTheme.border,
        ),
      ),
    );
  }
}

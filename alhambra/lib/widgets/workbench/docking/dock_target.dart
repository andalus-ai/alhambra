import 'package:flutter/material.dart';

class TabDropTarget {
  final String viewId;
  final Rect bounds;
  final int index;

  const TabDropTarget({
    required this.viewId,
    required this.bounds,
    required this.index,
  });
}

class DockTarget {
  final String groupId;
  final Rect bounds;
  final Rect tabStripBounds;
  final List<TabDropTarget> tabs;

  const DockTarget({
    required this.groupId,
    required this.bounds,
    required this.tabStripBounds,
    this.tabs = const [],
  });
}

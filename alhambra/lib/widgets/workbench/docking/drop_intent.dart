enum DockSide {
  left,
  right,
  top,
  bottom,
}

enum DockZone {
  tabStrip,
  center,
  left,
  right,
  top,
  bottom,
  outside,
}

sealed class DropIntent {
  const DropIntent();
}

final class NoDropIntent extends DropIntent {
  const NoDropIntent();
}

final class ReorderDropIntent extends DropIntent {
  final String targetGroupId;
  final int index;

  const ReorderDropIntent({
    required this.targetGroupId,
    required this.index,
  });
}

final class MoveToGroupDropIntent extends DropIntent {
  final String targetGroupId;

  const MoveToGroupDropIntent({
    required this.targetGroupId,
  });
}

final class SplitDropIntent extends DropIntent {
  final String targetGroupId;
  final DockSide side;

  const SplitDropIntent({
    required this.targetGroupId,
    required this.side,
  });
}

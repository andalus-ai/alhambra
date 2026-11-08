/// Sealed hierarchy representing deterministic repairs performed during layout restoration.
sealed class LayoutRepair {
  final String description;
  const LayoutRepair(this.description);
}

final class MigratedViewIdRepair extends LayoutRepair {
  final String oldViewId;
  final String newViewId;
  const MigratedViewIdRepair({required this.oldViewId, required this.newViewId})
      : super('Migrated view ID from "$oldViewId" to "$newViewId"');
}

final class RemovedBrokenGroupReferenceRepair extends LayoutRepair {
  final String groupId;
  const RemovedBrokenGroupReferenceRepair({required this.groupId})
      : super('Removed broken view group reference "$groupId"');
}

final class ClampedSplitRatioRepair extends LayoutRepair {
  final String splitNodeId;
  final double oldRatio;
  final double newRatio;
  const ClampedSplitRatioRepair({
    required this.splitNodeId,
    required this.oldRatio,
    required this.newRatio,
  }) : super('Clamped split ratio on node "$splitNodeId" from $oldRatio to $newRatio');
}

final class RestoredMissingDefaultAreaRepair extends LayoutRepair {
  final String areaName;
  const RestoredMissingDefaultAreaRepair({required this.areaName})
      : super('Restored missing root layout for area "$areaName"');
}

final class CreatedMissingGroupRepair extends LayoutRepair {
  final String groupId;
  const CreatedMissingGroupRepair({required this.groupId})
      : super('Created missing view group state for "$groupId"');
}

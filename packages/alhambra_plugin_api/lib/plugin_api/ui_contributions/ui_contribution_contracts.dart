import '../plugins/plugin_sdk_contracts.dart';

/// Stable definition identifier for an extension contribution.
final class ContributionId {
  final String value;
  const ContributionId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Runtime instance identifier for a rendered contribution in a specific window/session.
final class ContributionInstanceId {
  final String value;
  const ContributionInstanceId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionInstanceId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Declarative metadata for any UI contribution.
final class ContributionMetadata {
  final ContributionId id;
  final PluginId pluginId;
  final String? displayName;
  final int priority;

  const ContributionMetadata({
    required this.id,
    required this.pluginId,
    this.displayName,
    this.priority = 0,
  });
}

/// Base contract for all plugin UI contributions.
abstract interface class ExtensionUiContribution {
  ContributionId get id;
  PluginId get pluginId;
}

/// Stable host-owned workbench region identifier.
final class WorkbenchRegionId {
  final String value;
  const WorkbenchRegionId(this.value);

  static const primarySidebar = WorkbenchRegionId('alhambra.primarySidebar');
  static const secondarySidebar = WorkbenchRegionId(
    'alhambra.secondarySidebar',
  );
  static const editor = WorkbenchRegionId('alhambra.editor');
  static const bottomPanel = WorkbenchRegionId('alhambra.bottomPanel');
  static const statusBar = WorkbenchRegionId('alhambra.statusBar');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchRegionId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Placement descriptor for UI regions.
abstract interface class UiPlacement {
  WorkbenchRegionId get region;
}

final class RegionPlacement implements UiPlacement {
  @override
  final WorkbenchRegionId region;
  final int priority;

  const RegionPlacement({required this.region, this.priority = 0});
}

/// View placement hint provided by plugins.
final class ViewPlacementHint {
  final WorkbenchRegionId preferredRegion;
  final bool canMove;

  const ViewPlacementHint({required this.preferredRegion, this.canMove = true});
}

/// Relational ordering hint between contributions.
final class ContributionOrderHint {
  final ContributionId? before;
  final ContributionId? after;
  final int priority;

  const ContributionOrderHint({this.before, this.after, this.priority = 0});
}

/// Resource lease returned on contribution registration to guarantee lifecycle cleanup.
abstract interface class ContributionLease {
  ContributionId get contributionId;
  void dispose();
}

/// Context passed to a view factory when instantiating a view controller.
final class ViewRuntimeContext {
  final String viewId;
  final ContributionInstanceId instanceId;
  final Map<String, Object?> parameters;

  const ViewRuntimeContext({
    required this.viewId,
    required this.instanceId,
    this.parameters = const {},
  });
}

/// Abstract controller for a contributed view.
abstract interface class ViewController {
  void dispose();
}

/// Pure Dart boundary factory for creating view controllers without Flutter coupling.
abstract interface class ViewFactory {
  ViewController create(ViewRuntimeContext context);
}

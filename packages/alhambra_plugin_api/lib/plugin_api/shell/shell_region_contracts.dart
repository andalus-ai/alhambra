import '../ui/ui_contribution.dart';

abstract final class ShellRegions {
  static const top = 'alhambra.shell.top';
  static const activityBar = 'alhambra.shell.activityBar';
  static const primarySidebar = 'alhambra.shell.primarySidebar';
  static const main = 'alhambra.shell.main';
  static const secondarySidebar = 'alhambra.shell.secondarySidebar';
  static const bottom = 'alhambra.shell.bottom';
  static const status = 'alhambra.shell.status';
}

enum ShellRegionPlacement { top, left, center, right, bottom, overlay }

class ShellRegionConstraints {
  final double minSize;
  final double maxSize;
  final double defaultSize;

  const ShellRegionConstraints({
    required this.minSize,
    required this.maxSize,
    required this.defaultSize,
  });
}

class ShellRegionDefinition {
  final String id;
  final ShellRegionPlacement placement;
  final bool required;
  final bool collapsible;
  final bool allowContributions;
  final ShellRegionConstraints? constraints;

  const ShellRegionDefinition({
    required this.id,
    required this.placement,
    this.required = false,
    this.collapsible = true,
    this.allowContributions = true,
    this.constraints,
  });
}

enum ShellRegionContentKind { view, widget, action }

class ShellRegionContribution implements UiContribution {
  @override
  final String id;

  final String regionId;

  @override
  String get surfaceId => regionId;

  @override
  final ContributionOwner owner;

  @override
  final ContributionOrder order;

  @override
  final UiContributionScope scope;

  @override
  final UiContributionPredicate? when;

  @override
  final Set<String> dependencies;

  final ShellRegionContentKind kind;
  final String? targetViewId;
  final String? commandId;

  const ShellRegionContribution({
    required this.id,
    required this.regionId,
    required this.kind,
    this.targetViewId,
    this.commandId,
    this.owner = ContributionOwner.core,
    this.order = const ContributionOrder.defaultOrder(),
    this.scope = const GlobalUiScope(),
    this.when,
    this.dependencies = const {},
  });
}

class ShellLayoutState {
  final Set<String> hiddenRegions;
  final Set<String> collapsedRegions;
  final Map<String, double> regionSizes;
  final Map<String, String> activeContributionByRegion;

  const ShellLayoutState({
    this.hiddenRegions = const {},
    this.collapsedRegions = const {},
    this.regionSizes = const {},
    this.activeContributionByRegion = const {},
  });

  bool isVisible(String regionId) => !hiddenRegions.contains(regionId);
  bool isCollapsed(String regionId) => collapsedRegions.contains(regionId);
  double? sizeOf(String regionId) => regionSizes[regionId];
  String? activeContribution(String regionId) =>
      activeContributionByRegion[regionId];

  ShellLayoutState copyWith({
    Set<String>? hiddenRegions,
    Set<String>? collapsedRegions,
    Map<String, double>? regionSizes,
    Map<String, String>? activeContributionByRegion,
  }) {
    return ShellLayoutState(
      hiddenRegions: hiddenRegions ?? this.hiddenRegions,
      collapsedRegions: collapsedRegions ?? this.collapsedRegions,
      regionSizes: regionSizes ?? this.regionSizes,
      activeContributionByRegion:
          activeContributionByRegion ?? this.activeContributionByRegion,
    );
  }

  Map<String, dynamic> toJson() => {
    'hiddenRegions': hiddenRegions.toList(),
    'collapsedRegions': collapsedRegions.toList(),
    'regionSizes': regionSizes,
    'activeContributionByRegion': activeContributionByRegion,
  };

  factory ShellLayoutState.fromJson(
    Map<String, dynamic> json,
  ) => ShellLayoutState(
    hiddenRegions:
        (json['hiddenRegions'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
    collapsedRegions:
        (json['collapsedRegions'] as List<dynamic>?)?.cast<String>().toSet() ??
        {},
    regionSizes:
        (json['regionSizes'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        {},
    activeContributionByRegion:
        (json['activeContributionByRegion'] as Map<String, dynamic>?)
            ?.cast<String, String>() ??
        {},
  );
}

abstract interface class ShellRegionController {
  void show(String regionId);
  void hide(String regionId);
  void collapse(String regionId);
  void expand(String regionId);
  void resize(String regionId, double size);
  void activate(String regionId, String contributionId);
}

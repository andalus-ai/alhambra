import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'shell_region_controller.dart';
import 'shell_region_registry.dart';

class ResolvedShellRegion {
  final ShellRegionDefinition definition;
  final bool visible;
  final bool collapsed;
  final double? size;
  final List<ShellRegionContribution> contributions;

  const ResolvedShellRegion({
    required this.definition,
    required this.visible,
    required this.collapsed,
    required this.size,
    required this.contributions,
  });
}

abstract interface class ShellRegionResolver {
  ResolvedShellRegion resolve(String regionId);
}

class DefaultShellRegionResolver implements ShellRegionResolver {
  final ShellRegionRegistry registry;
  final DefaultShellRegionController controller;

  const DefaultShellRegionResolver({
    required this.registry,
    required this.controller,
  });

  @override
  ResolvedShellRegion resolve(String regionId) {
    final def =
        registry.definition(regionId) ??
        ShellRegionDefinition(
          id: regionId,
          placement: ShellRegionPlacement.center,
        );

    final state = controller.state;
    final isVisible = def.required || state.isVisible(regionId);
    final isCollapsed = state.isCollapsed(regionId);
    final size = state.sizeOf(regionId) ?? def.constraints?.defaultSize;
    final contributions = registry.contributionsFor(regionId).toList();

    return ResolvedShellRegion(
      definition: def,
      visible: isVisible,
      collapsed: isCollapsed,
      size: size,
      contributions: contributions,
    );
  }
}

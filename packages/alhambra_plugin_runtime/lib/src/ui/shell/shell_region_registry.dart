import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

abstract interface class ShellRegionRegistry {
  void define(ShellRegionDefinition definition);
  void register(ShellRegionContribution contribution);
  void unregister(String contributionId);
  void unregisterOwner(String ownerId);
  ShellRegionDefinition? definition(String regionId);
  Iterable<ShellRegionDefinition> get allDefinitions;
  Iterable<ShellRegionContribution> contributionsFor(String regionId);
  Iterable<ShellRegionContribution> get allContributions;
}

class InMemoryShellRegionRegistry implements ShellRegionRegistry {
  final Map<String, ShellRegionDefinition> _definitions = {};
  final Map<String, ShellRegionContribution> _contributions = {};

  InMemoryShellRegionRegistry() {
    // Define standard shell regions
    _defineDefaultRegions();
  }

  void _defineDefaultRegions() {
    define(
      const ShellRegionDefinition(
        id: ShellRegions.top,
        placement: ShellRegionPlacement.top,
        required: true,
        collapsible: false,
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.activityBar,
        placement: ShellRegionPlacement.left,
        required: false,
        collapsible: true,
        constraints: ShellRegionConstraints(
          minSize: 48,
          maxSize: 60,
          defaultSize: 48,
        ),
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.primarySidebar,
        placement: ShellRegionPlacement.left,
        required: false,
        collapsible: true,
        constraints: ShellRegionConstraints(
          minSize: 180,
          maxSize: 600,
          defaultSize: 260,
        ),
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.main,
        placement: ShellRegionPlacement.center,
        required: true,
        collapsible: false,
        allowContributions: false,
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.secondarySidebar,
        placement: ShellRegionPlacement.right,
        required: false,
        collapsible: true,
        constraints: ShellRegionConstraints(
          minSize: 200,
          maxSize: 600,
          defaultSize: 280,
        ),
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.bottom,
        placement: ShellRegionPlacement.bottom,
        required: false,
        collapsible: true,
        constraints: ShellRegionConstraints(
          minSize: 120,
          maxSize: 600,
          defaultSize: 220,
        ),
      ),
    );
    define(
      const ShellRegionDefinition(
        id: ShellRegions.status,
        placement: ShellRegionPlacement.bottom,
        required: true,
        collapsible: false,
        constraints: ShellRegionConstraints(
          minSize: 24,
          maxSize: 32,
          defaultSize: 24,
        ),
      ),
    );
  }

  @override
  void define(ShellRegionDefinition definition) {
    _definitions[definition.id] = definition;
  }

  @override
  void register(ShellRegionContribution contribution) {
    _contributions[contribution.id] = contribution;
  }

  @override
  void unregister(String contributionId) {
    _contributions.remove(contributionId);
  }

  @override
  void unregisterOwner(String ownerId) {
    _contributions.removeWhere((_, c) => c.owner.id == ownerId);
  }

  @override
  ShellRegionDefinition? definition(String regionId) => _definitions[regionId];

  @override
  Iterable<ShellRegionDefinition> get allDefinitions => _definitions.values;

  @override
  Iterable<ShellRegionContribution> contributionsFor(String regionId) =>
      _contributions.values.where((c) => c.regionId == regionId);

  @override
  Iterable<ShellRegionContribution> get allContributions =>
      _contributions.values;
}

import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'shell_region_registry.dart';

class DefaultShellRegionController implements ShellRegionController {
  final ShellRegionRegistry registry;
  ShellLayoutState _state;
  final StreamController<ShellLayoutState> _stateController =
      StreamController<ShellLayoutState>.broadcast();

  DefaultShellRegionController({
    required this.registry,
    ShellLayoutState initialState = const ShellLayoutState(),
  }) : _state = initialState;

  ShellLayoutState get state => _state;
  Stream<ShellLayoutState> get stateStream => _stateController.stream;

  @override
  void show(String regionId) {
    if (_state.hiddenRegions.contains(regionId)) {
      final updatedHidden = Set<String>.from(_state.hiddenRegions)
        ..remove(regionId);
      _updateState(_state.copyWith(hiddenRegions: updatedHidden));
    }
  }

  @override
  void hide(String regionId) {
    final def = registry.definition(regionId);
    if (def?.required == true) return; // Cannot hide required regions

    if (!_state.hiddenRegions.contains(regionId)) {
      final updatedHidden = Set<String>.from(_state.hiddenRegions)
        ..add(regionId);
      _updateState(_state.copyWith(hiddenRegions: updatedHidden));
    }
  }

  @override
  void collapse(String regionId) {
    final def = registry.definition(regionId);
    if (def?.collapsible == false) return;

    if (!_state.collapsedRegions.contains(regionId)) {
      final updatedCollapsed = Set<String>.from(_state.collapsedRegions)
        ..add(regionId);
      _updateState(_state.copyWith(collapsedRegions: updatedCollapsed));
    }
  }

  @override
  void expand(String regionId) {
    if (_state.collapsedRegions.contains(regionId)) {
      final updatedCollapsed = Set<String>.from(_state.collapsedRegions)
        ..remove(regionId);
      _updateState(_state.copyWith(collapsedRegions: updatedCollapsed));
    }
  }

  @override
  void resize(String regionId, double size) {
    final def = registry.definition(regionId);
    double targetSize = size;

    if (def?.constraints != null) {
      targetSize = size.clamp(
        def!.constraints!.minSize,
        def.constraints!.maxSize,
      );
    }

    final updatedSizes = Map<String, double>.from(_state.regionSizes)
      ..[regionId] = targetSize;
    _updateState(_state.copyWith(regionSizes: updatedSizes));
  }

  @override
  void activate(String regionId, String contributionId) {
    final updatedActive = Map<String, String>.from(
      _state.activeContributionByRegion,
    )..[regionId] = contributionId;
    _updateState(_state.copyWith(activeContributionByRegion: updatedActive));
  }

  void _updateState(ShellLayoutState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _stateController.close();
  }
}

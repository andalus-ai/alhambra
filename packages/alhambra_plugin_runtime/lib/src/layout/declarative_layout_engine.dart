import 'dart:async';
import 'dart:convert';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Layout migration registry handling schema upgrades.
class DefaultLayoutMigrationRegistry {
  final Map<int, DeclarativeLayoutMigration> _migrations = {};

  void register(DeclarativeLayoutMigration migration) {
    _migrations[migration.fromVersion] = migration;
  }

  Map<String, Object?> migrateToLatest(
    Map<String, Object?> input,
    int targetVersion,
  ) {
    var current = Map<String, Object?>.from(input);
    var currentVersion = current['version'] as int? ?? 1;

    while (currentVersion < targetVersion) {
      final mig = _migrations[currentVersion];
      if (mig == null) break;
      current = mig.migrate(current);
      currentVersion = mig.toVersion;
      current['version'] = currentVersion;
    }

    return current;
  }
}

/// Serializes and deserializes declarative layout trees to/from JSON.
class LayoutSerializer {
  final DefaultLayoutMigrationRegistry migrationRegistry;
  static const currentSchemaVersion = 1;

  LayoutSerializer({DefaultLayoutMigrationRegistry? migrationRegistry})
    : migrationRegistry = migrationRegistry ?? DefaultLayoutMigrationRegistry();

  String serialize(DeclarativeLayoutState state) {
    final map = {
      'version': currentSchemaVersion,
      'tree': state.tree.toJson(),
      'openViews': state.openViews.map((v) => v.value).toList(),
      'pinnedViews': state.pinnedViews.map((v) => v.value).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  DeclarativeLayoutState deserialize(
    String jsonString, {
    Set<String> knownPluginViewIds = const {},
  }) {
    final rawMap = jsonDecode(jsonString) as Map<String, dynamic>;
    final migrated = migrationRegistry.migrateToLatest(
      rawMap,
      currentSchemaVersion,
    );

    final treeMap = migrated['tree'] as Map<String, dynamic>? ?? {};
    final rootMap = treeMap['root'] as Map<String, dynamic>? ?? {};

    final root = _parseNode(rootMap, knownPluginViewIds);
    final openViews = (migrated['openViews'] as List<dynamic>? ?? [])
        .map((e) => ViewInstanceId(e.toString()))
        .toSet();
    final pinnedViews = (migrated['pinnedViews'] as List<dynamic>? ?? [])
        .map((e) => ViewInstanceId(e.toString()))
        .toSet();

    return DeclarativeLayoutState(
      tree: DeclarativeLayoutTree(root: root),
      openViews: openViews,
      pinnedViews: pinnedViews,
    );
  }

  DeclarativeLayoutNode _parseNode(
    Map<String, dynamic> map,
    Set<String> knownPluginViewIds,
  ) {
    final type = map['type'] as String? ?? 'placeholder';
    switch (type) {
      case 'view':
        final instId = map['instanceId'] as String? ?? '';
        return LayoutViewNode(ViewInstanceId(instId));
      case 'split':
        final dirName = map['direction'] as String? ?? 'horizontal';
        final dir = dirName == 'vertical'
            ? DeclarativeSplitDirection.vertical
            : DeclarativeSplitDirection.horizontal;
        final ratio = (map['ratio'] as num?)?.toDouble() ?? 0.5;
        final firstMap = map['first'] as Map<String, dynamic>? ?? {};
        final secondMap = map['second'] as Map<String, dynamic>? ?? {};
        return DeclarativeSplitNode(
          direction: dir,
          ratio: ratio,
          first: _parseNode(firstMap, knownPluginViewIds),
          second: _parseNode(secondMap, knownPluginViewIds),
        );
      case 'tabs':
        final tabList = (map['tabs'] as List<dynamic>? ?? [])
            .map((e) => ViewInstanceId(e.toString()))
            .toList();
        final activeIdx = map['activeIndex'] as int? ?? 0;
        return DeclarativeTabNode(tabs: tabList, activeIndex: activeIdx);
      case 'panel':
        final panelId = map['panelId'] as String? ?? '';
        final viewList = (map['views'] as List<dynamic>? ?? [])
            .map((e) => ViewInstanceId(e.toString()))
            .toList();
        final activeIdx = map['activeIndex'] as int? ?? 0;
        final visible = map['visible'] as bool? ?? true;
        return DeclarativePanelNode(
          panelId: panelId,
          views: viewList,
          activeIndex: activeIdx,
          visible: visible,
        );
      case 'placeholder':
      default:
        final msg = map['message'] as String? ?? 'View unavailable';
        final viewId = map['viewId'] as String?;
        return DeclarativePlaceholderNode(message: msg, viewId: viewId);
    }
  }
}

/// Controller managing declarative layout state changes and commands.
class DefaultDeclarativeLayoutController {
  DeclarativeLayoutState _state;
  final _stateController = StreamController<DeclarativeLayoutState>.broadcast(
    sync: true,
  );

  DefaultDeclarativeLayoutController({DeclarativeLayoutState? initialState})
    : _state =
          initialState ??
          DeclarativeLayoutState(
            tree: const DeclarativeLayoutTree(
              root: DeclarativePlaceholderNode(message: 'Empty Workspace'),
            ),
            openViews: const {},
            pinnedViews: const {},
          );

  DeclarativeLayoutState get state => _state;
  Stream<DeclarativeLayoutState> get onStateChanged => _stateController.stream;

  void openView(ViewInstanceId instanceId) {
    final open = Set<ViewInstanceId>.from(_state.openViews)..add(instanceId);
    final newRoot = _insertViewNode(_state.tree.root, instanceId);
    _setState(
      _state.copyWith(
        tree: DeclarativeLayoutTree(root: newRoot),
        openViews: open,
      ),
    );
  }

  void closeView(ViewInstanceId instanceId) {
    final open = Set<ViewInstanceId>.from(_state.openViews)..remove(instanceId);
    final pinned = Set<ViewInstanceId>.from(_state.pinnedViews)
      ..remove(instanceId);
    final newRoot = _removeViewNode(_state.tree.root, instanceId);
    _setState(
      _state.copyWith(
        tree: DeclarativeLayoutTree(root: newRoot),
        openViews: open,
        pinnedViews: pinned,
      ),
    );
  }

  void pinView(ViewInstanceId instanceId) {
    final pinned = Set<ViewInstanceId>.from(_state.pinnedViews)
      ..add(instanceId);
    _setState(_state.copyWith(pinnedViews: pinned));
  }

  void unpinView(ViewInstanceId instanceId) {
    final pinned = Set<ViewInstanceId>.from(_state.pinnedViews)
      ..remove(instanceId);
    _setState(_state.copyWith(pinnedViews: pinned));
  }

  void split(ViewInstanceId instanceId, DeclarativeSplitDirection direction) {
    final newRoot = _splitViewNode(_state.tree.root, instanceId, direction);
    _setState(_state.copyWith(tree: DeclarativeLayoutTree(root: newRoot)));
  }

  void dispatchCommand(DeclarativeLayoutCommand command) {
    switch (command) {
      case DeclarativeOpenViewCommand(:final viewId):
        openView(
          ViewInstanceId('${viewId}_${DateTime.now().millisecondsSinceEpoch}'),
        );
        break;
      case DeclarativeSplitViewCommand(:final instanceId, :final direction):
        split(instanceId, direction);
        break;
      case DeclarativeResizeSplitCommand():
        // Handled in tree transformation
        break;
      case DeclarativeMoveViewCommand():
        // Handled in tree move
        break;
    }
  }

  DeclarativeLayoutNode _insertViewNode(
    DeclarativeLayoutNode current,
    ViewInstanceId instanceId,
  ) {
    if (current is DeclarativePlaceholderNode) {
      return LayoutViewNode(instanceId);
    }
    if (current is DeclarativeTabNode) {
      final tabs = List<ViewInstanceId>.from(current.tabs);
      if (!tabs.contains(instanceId)) tabs.add(instanceId);
      return DeclarativeTabNode(
        tabs: tabs,
        activeIndex: tabs.indexOf(instanceId),
      );
    }
    return DeclarativeTabNode(tabs: [instanceId], activeIndex: 0);
  }

  DeclarativeLayoutNode _removeViewNode(
    DeclarativeLayoutNode current,
    ViewInstanceId instanceId,
  ) {
    if (current is LayoutViewNode && current.instanceId == instanceId) {
      return const DeclarativePlaceholderNode(message: 'No active view');
    }
    if (current is DeclarativeTabNode) {
      final tabs = List<ViewInstanceId>.from(current.tabs)..remove(instanceId);
      if (tabs.isEmpty)
        return const DeclarativePlaceholderNode(message: 'No active view');
      final activeIdx = current.activeIndex >= tabs.length
          ? tabs.length - 1
          : current.activeIndex;
      return DeclarativeTabNode(tabs: tabs, activeIndex: activeIdx);
    }
    return current;
  }

  DeclarativeLayoutNode _splitViewNode(
    DeclarativeLayoutNode current,
    ViewInstanceId instanceId,
    DeclarativeSplitDirection direction,
  ) {
    if (current is LayoutViewNode && current.instanceId == instanceId) {
      return DeclarativeSplitNode(
        direction: direction,
        ratio: 0.5,
        first: current,
        second: const DeclarativePlaceholderNode(message: 'Split Pane'),
      );
    }
    return current;
  }

  void _setState(DeclarativeLayoutState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _stateController.close();
  }
}

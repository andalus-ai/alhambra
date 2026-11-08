import '../runtime_scope/runtime_scope_contracts.dart';
import '../plugins/plugin_sdk_contracts.dart';

enum DeclarativeSplitDirection {
  horizontal,
  vertical,
}

/// Abstract AST node in a declarative layout tree.
sealed class DeclarativeLayoutNode {
  const DeclarativeLayoutNode();
  Map<String, Object?> toJson();
}

final class LayoutViewNode extends DeclarativeLayoutNode {
  final ViewInstanceId instanceId;
  const LayoutViewNode(this.instanceId);

  @override
  Map<String, Object?> toJson() => {
        'type': 'view',
        'instanceId': instanceId.value,
      };
}

final class DeclarativeSplitNode extends DeclarativeLayoutNode {
  final DeclarativeSplitDirection direction;
  final double ratio;
  final DeclarativeLayoutNode first;
  final DeclarativeLayoutNode second;

  const DeclarativeSplitNode({
    required this.direction,
    required this.ratio,
    required this.first,
    required this.second,
  });

  @override
  Map<String, Object?> toJson() => {
        'type': 'split',
        'direction': direction.name,
        'ratio': ratio,
        'first': first.toJson(),
        'second': second.toJson(),
      };
}

final class DeclarativeTabNode extends DeclarativeLayoutNode {
  final List<ViewInstanceId> tabs;
  final int activeIndex;

  const DeclarativeTabNode({
    required this.tabs,
    required this.activeIndex,
  });

  @override
  Map<String, Object?> toJson() => {
        'type': 'tabs',
        'tabs': tabs.map((t) => t.value).toList(),
        'activeIndex': activeIndex,
      };
}

final class DeclarativePanelNode extends DeclarativeLayoutNode {
  final String panelId;
  final List<ViewInstanceId> views;
  final int activeIndex;
  final bool visible;

  const DeclarativePanelNode({
    required this.panelId,
    required this.views,
    required this.activeIndex,
    required this.visible,
  });

  @override
  Map<String, Object?> toJson() => {
        'type': 'panel',
        'panelId': panelId,
        'views': views.map((v) => v.value).toList(),
        'activeIndex': activeIndex,
        'visible': visible,
      };
}

final class DeclarativePlaceholderNode extends DeclarativeLayoutNode {
  final String message;
  final String? viewId;

  const DeclarativePlaceholderNode({
    required this.message,
    this.viewId,
  });

  @override
  Map<String, Object?> toJson() => {
        'type': 'placeholder',
        'message': message,
        if (viewId != null) 'viewId': viewId,
      };
}

/// Declarative layout tree container.
final class DeclarativeLayoutTree {
  final DeclarativeLayoutNode root;

  const DeclarativeLayoutTree({required this.root});

  Map<String, Object?> toJson() => {
        'root': root.toJson(),
      };
}

/// Immutable snapshot of declarative workspace layout state.
final class DeclarativeLayoutState {
  final DeclarativeLayoutTree tree;
  final Set<ViewInstanceId> openViews;
  final Set<ViewInstanceId> pinnedViews;

  const DeclarativeLayoutState({
    required this.tree,
    required this.openViews,
    required this.pinnedViews,
  });

  DeclarativeLayoutState copyWith({
    DeclarativeLayoutTree? tree,
    Set<ViewInstanceId>? openViews,
    Set<ViewInstanceId>? pinnedViews,
  }) {
    return DeclarativeLayoutState(
      tree: tree ?? this.tree,
      openViews: openViews ?? this.openViews,
      pinnedViews: pinnedViews ?? this.pinnedViews,
    );
  }
}

/// Declarative commands for layout manipulation.
sealed class DeclarativeLayoutCommand {
  const DeclarativeLayoutCommand();
}

final class DeclarativeOpenViewCommand extends DeclarativeLayoutCommand {
  final String viewId;
  final Object? arguments;

  const DeclarativeOpenViewCommand(this.viewId, {this.arguments});
}

final class DeclarativeSplitViewCommand extends DeclarativeLayoutCommand {
  final ViewInstanceId instanceId;
  final DeclarativeSplitDirection direction;

  const DeclarativeSplitViewCommand({
    required this.instanceId,
    required this.direction,
  });
}

final class DeclarativeResizeSplitCommand extends DeclarativeLayoutCommand {
  final String splitId;
  final double ratio;

  const DeclarativeResizeSplitCommand({
    required this.splitId,
    required this.ratio,
  });
}

final class DeclarativeMoveViewCommand extends DeclarativeLayoutCommand {
  final ViewInstanceId instanceId;
  final String targetRegion;

  const DeclarativeMoveViewCommand({
    required this.instanceId,
    required this.targetRegion,
  });
}

/// Abstract interface for migrating persisted layout schemas across application versions.
abstract interface class DeclarativeLayoutMigration {
  int get fromVersion;
  int get toVersion;
  Map<String, Object?> migrate(Map<String, Object?> input);
}

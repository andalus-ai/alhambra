import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

typedef CommandExecutionHandler = Future<ResourceMutationResult> Function(
  ResourceCommand command,
  InteractionContext context,
);

/// Central interaction and command registration service.
class DefaultInteractionRegistry {
  final Map<String, CommandDefinition> _definitions = {};
  final Map<String, CommandExecutionHandler> _handlers = {};
  final List<DeclarativeMenuContribution> _menus = [];
  final List<DeclarativeToolbarContribution> _toolbars = [];
  final List<DeclarativeContextMenuContribution> _contextMenus = [];
  final List<KeybindingContribution> _keybindings = [];

  void registerCommand(
    CommandDefinition definition, {
    CommandExecutionHandler? handler,
  }) {
    _definitions[definition.type.value] = definition;
    if (handler != null) {
      _handlers[definition.type.value] = handler;
    }
  }

  void unregisterCommand(CommandType type) {
    _definitions.remove(type.value);
    _handlers.remove(type.value);
  }

  void registerHandler(CommandType type, CommandExecutionHandler handler) {
    _handlers[type.value] = handler;
  }

  CommandDefinition? findCommand(CommandType type) => _definitions[type.value];
  CommandExecutionHandler? findHandler(CommandType type) =>
      _handlers[type.value];

  void registerMenu(DeclarativeMenuContribution contribution) {
    _menus.add(contribution);
  }

  void registerToolbar(DeclarativeToolbarContribution contribution) {
    _toolbars.add(contribution);
  }

  void registerContextMenu(DeclarativeContextMenuContribution contribution) {
    _contextMenus.add(contribution);
  }

  void registerKeybinding(KeybindingContribution contribution) {
    _keybindings.add(contribution);
  }

  List<DeclarativeMenuContribution> getMenuContributions(String menuId) =>
      _menus.where((m) => m.menuId == menuId).toList();

  List<DeclarativeToolbarContribution> getToolbarContributions(
    String toolbarId,
  ) => _toolbars.where((t) => t.toolbarId == toolbarId).toList();

  List<DeclarativeContextMenuContribution> getContextMenuContributions(
    String contextMenuId,
  ) => _contextMenus.where((c) => c.contextMenuId == contextMenuId).toList();

  List<KeybindingContribution> getKeybindings() =>
      List.unmodifiable(_keybindings);

  void clear() {
    _definitions.clear();
    _handlers.clear();
    _menus.clear();
    _toolbars.clear();
    _contextMenus.clear();
    _keybindings.clear();
  }
}

/// Central dispatcher for executing registered resource commands.
class DefaultCommandDispatcher implements CommandDispatcher {
  final DefaultInteractionRegistry registry;

  DefaultCommandDispatcher({required this.registry});

  @override
  Future<ResourceMutationResult> dispatch(
    ResourceCommand command,
    InteractionContext context,
  ) async {
    final definition = registry.findCommand(command.type);
    if (definition == null) {
      return ResourceMutationResult.failed(
        'Command "${command.type.value}" is not registered',
      );
    }

    final availability = await definition.availability.evaluate(context);
    if (!availability.enabled) {
      return ResourceMutationResult.failed(
        availability.disabledReason ??
            'Command "${command.type.value}" is currently disabled',
      );
    }

    final handler = registry.findHandler(command.type);
    if (handler == null) {
      return ResourceMutationResult.failed(
        'No execution handler registered for command "${command.type.value}"',
      );
    }

    return await handler(command, context);
  }
}

/// Resolves declarative menu contributions into an active MenuModel.
class DefaultMenuModelResolver implements MenuModelResolver {
  final DefaultInteractionRegistry registry;

  DefaultMenuModelResolver({required this.registry});

  @override
  Future<MenuModel> resolve(String menuId, InteractionContext context) async {
    final rawContributions = registry.getMenuContributions(menuId);
    final sorted = _sortContributions(rawContributions);

    final items = <MenuItemModel>[];
    String? currentGroup;

    for (final contrib in sorted) {
      final definition = registry.findCommand(contrib.command);
      if (definition == null) continue;

      final avail = await definition.availability.evaluate(context);
      if (!avail.visible) continue;

      if (contrib.group != null &&
          contrib.group != currentGroup &&
          items.isNotEmpty) {
        items.add(const SeparatorItem());
        currentGroup = contrib.group;
      }

      items.add(
        CommandMenuItem(
          command: contrib.command,
          title: definition.title,
          enabled: avail.enabled,
          disabledReason: avail.disabledReason,
          icon: definition.icon,
        ),
      );
    }

    return MenuModel(id: menuId, items: items);
  }

  List<DeclarativeMenuContribution> _sortContributions(
    List<DeclarativeMenuContribution> contributions,
  ) {
    final list = List<DeclarativeMenuContribution>.from(contributions);
    list.sort(
      (a, b) => b.priority.compareTo(a.priority),
    ); // Highest priority first
    return list;
  }
}

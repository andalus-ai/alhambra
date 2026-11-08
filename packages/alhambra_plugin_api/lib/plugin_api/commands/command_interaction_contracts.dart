import '../runtime_scope/runtime_scope_contracts.dart';

/// Globally stable namespaced command type.
final class CommandType {
  final String namespace;
  final String name;

  const CommandType(this.namespace, this.name);

  String get value => '$namespace.$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandType &&
          runtimeType == other.runtimeType &&
          namespace == other.namespace &&
          name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);

  @override
  String toString() => value;
}

/// Icon metadata for commands.
final class CommandIcon {
  final String iconId;
  const CommandIcon(this.iconId);
}

enum CommandVisibility { visible, hidden }
enum CommandEnablement { enabled, disabled }

/// Evaluation result for a command's presentation state.
final class CommandAvailabilityResult {
  final bool visible;
  final bool enabled;
  final String? disabledReason;

  const CommandAvailabilityResult({
    required this.visible,
    required this.enabled,
    this.disabledReason,
  });

  const CommandAvailabilityResult.always()
      : visible = true,
        enabled = true,
        disabledReason = null;

  const CommandAvailabilityResult.disabled([this.disabledReason])
      : visible = true,
        enabled = false;

  const CommandAvailabilityResult.hidden()
      : visible = false,
        enabled = false,
        disabledReason = null;
}

/// Context passed to availability evaluation and command dispatch.
final class InteractionContext {
  final WindowId? windowId;
  final WorkspaceId? workspaceId;
  final ViewInstanceId? viewId;
  final Uri? resource;
  final Map<String, Object?> extra;

  const InteractionContext({
    this.windowId,
    this.workspaceId,
    this.viewId,
    this.resource,
    this.extra = const {},
  });
}

/// Interface for evaluating when a command is visible and enabled.
abstract interface class CommandAvailability {
  static const always = _AlwaysCommandAvailability();
  Future<CommandAvailabilityResult> evaluate(InteractionContext context);
}

class _AlwaysCommandAvailability implements CommandAvailability {
  const _AlwaysCommandAvailability();
  @override
  Future<CommandAvailabilityResult> evaluate(InteractionContext context) async =>
      const CommandAvailabilityResult.always();
}

/// Declarative metadata for a command.
final class CommandDefinition {
  final CommandType type;
  final String title;
  final String? description;
  final CommandIcon? icon;
  final CommandAvailability availability;

  const CommandDefinition({
    required this.type,
    required this.title,
    this.description,
    this.icon,
    this.availability = CommandAvailability.always,
  });
}

/// Request to execute a command with parameters.
final class ResourceCommand {
  final CommandType type;
  final Map<String, Object?> parameters;
  final Uri? resourceUri;

  const ResourceCommand({
    required this.type,
    this.parameters = const {},
    this.resourceUri,
  });
}

/// Result of executing a command.
final class ResourceMutationResult {
  final bool success;
  final String? message;
  final Map<String, Object?> data;

  const ResourceMutationResult({
    required this.success,
    this.message,
    this.data = const {},
  });

  const ResourceMutationResult.ok([this.message, this.data = const {}])
      : success = true;

  const ResourceMutationResult.failed(this.message, [this.data = const {}])
      : success = false;
}

/// Central dispatcher for executing commands.
abstract interface class CommandDispatcher {
  Future<ResourceMutationResult> dispatch(
    ResourceCommand command,
    InteractionContext context,
  );
}

/// Base contract for UI interaction contributions.
abstract interface class InteractionContribution {
  String get id;
  CommandType get command;
  int get priority;
}

/// Standard menu IDs.
abstract final class MenuIds {
  static const main = 'shell.main';
  static const file = 'shell.file';
  static const edit = 'shell.edit';
  static const view = 'shell.view';
  static const resourceContext = 'resource.context';
  static const editorContext = 'editor.context';
  static const editorToolbar = 'editor.toolbar';
}

/// Grouping header inside a menu.
final class MenuGroup {
  final String id;
  final String? title;

  const MenuGroup({
    required this.id,
    this.title,
  });
}

/// Declarative contribution to a menu.
final class DeclarativeMenuContribution implements InteractionContribution {
  @override
  final String id;
  @override
  final CommandType command;
  final String menuId;
  final String? group;
  final String? before;
  final String? after;
  @override
  final int priority;

  const DeclarativeMenuContribution({
    required this.id,
    required this.command,
    required this.menuId,
    this.group,
    this.before,
    this.after,
    this.priority = 0,
  });
}

/// UI-neutral menu models.
sealed class MenuItemModel {
  const MenuItemModel();
}

final class CommandMenuItem extends MenuItemModel {
  final CommandType command;
  final String title;
  final bool enabled;
  final String? disabledReason;
  final CommandIcon? icon;

  const CommandMenuItem({
    required this.command,
    required this.title,
    required this.enabled,
    this.disabledReason,
    this.icon,
  });
}

final class SubmenuItem extends MenuItemModel {
  final String id;
  final String title;
  final List<MenuItemModel> items;

  const SubmenuItem({
    required this.id,
    required this.title,
    required this.items,
  });
}

final class SeparatorItem extends MenuItemModel {
  const SeparatorItem();
}

final class MenuModel {
  final String id;
  final List<MenuItemModel> items;

  const MenuModel({
    required this.id,
    required this.items,
  });
}

/// Resolves declarative menu contributions into an active MenuModel.
abstract interface class MenuModelResolver {
  Future<MenuModel> resolve(
    String menuId,
    InteractionContext context,
  );
}

/// Declarative contribution to a toolbar.
final class DeclarativeToolbarContribution implements InteractionContribution {
  @override
  final String id;
  @override
  final CommandType command;
  final String toolbarId;
  @override
  final int priority;

  const DeclarativeToolbarContribution({
    required this.id,
    required this.command,
    required this.toolbarId,
    this.priority = 0,
  });
}

/// Declarative contribution to a context menu.
final class DeclarativeContextMenuContribution implements InteractionContribution {
  @override
  final String id;
  @override
  final CommandType command;
  final String contextMenuId;
  final String? resourceType;
  @override
  final int priority;

  const DeclarativeContextMenuContribution({
    required this.id,
    required this.command,
    required this.contextMenuId,
    this.resourceType,
    this.priority = 0,
  });
}

/// Keybinding declaration.
final class Keybinding {
  final String key;
  final bool ctrl;
  final bool meta;
  final bool shift;
  final bool alt;

  const Keybinding({
    required this.key,
    this.ctrl = false,
    this.meta = false,
    this.shift = false,
    this.alt = false,
  });
}

final class KeybindingContribution implements InteractionContribution {
  @override
  final String id;
  @override
  final CommandType command;
  final Keybinding keybinding;
  final String? when;
  @override
  final int priority;

  const KeybindingContribution({
    required this.id,
    required this.command,
    required this.keybinding,
    this.when,
    this.priority = 0,
  });
}

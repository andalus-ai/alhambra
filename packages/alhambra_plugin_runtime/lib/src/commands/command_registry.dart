import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// The command registry is responsible for registering and managing
/// commands.
///
/// It is used by the command service to get the current context.
class CommandRegistry implements OwnerCleanup {
  /// The commands.
  final Map<String, AppCommand> _commands = {};

  /// The commands by owner.
  final Map<String, Set<String>> _commandsByOwner = {};

  /// Registers a command.
  ///
  /// It is called by the command service to register a command.
  void register(AppCommand command, {String ownerId = 'core'}) {
    if (_commands.containsKey(command.id)) {
      throw StateError('Command already registered: ${command.id}');
    }
    _commands[command.id] = command;
    _commandsByOwner.putIfAbsent(ownerId, () => <String>{}).add(command.id);
  }

  /// Returns a command by its ID.
  ///
  /// It is called by the command service to get a command.
  AppCommand? get(String id) => _commands[id];

  /// Returns true if a command with the given ID exists.
  ///
  /// It is called by the command service to check if a command exists.
  bool contains(String id) => _commands.containsKey(id);

  /// Returns all commands.
  List<AppCommand> get all => List.unmodifiable(_commands.values.toList());

  /// Returns all commands.
  List<AppCommand> getAll() => all;

  /// Searches for commands by a query.
  List<AppCommand> search(String query) {
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase();
    return all
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              (c.subtitle?.toLowerCase().contains(q) ?? false) ||
              c.category.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Executes a command.
  ///
  /// It is called by the command service to execute a command.
  Future<void> execute(String id, CommandContext context) async {
    final command = _commands[id];
    if (command == null) {
      throw StateError('Command not found: $id');
    }
    if (command.action != null) {
      await command.action!(context);
    }
  }

  /// Unregisters all commands for a given owner.
  ///
  /// It is called by the plugin host to unregister commands.
  @override
  void unregisterAllForOwner(String ownerId) {
    final ids = _commandsByOwner.remove(ownerId);
    if (ids == null) return;
    for (final id in ids) {
      _commands.remove(id);
    }
  }
}

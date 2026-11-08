import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../extensions/contribution_scope.dart';
import '../extensions/extension_runtime.dart';

class _RuntimeUiApi implements PluginUiApi {
  final RuntimePluginContext context;
  _RuntimeUiApi(this.context);

  @override
  ViewRegistrar get views => _ViewRegistrar(context);

  @override
  ActivityBarRegistrar get activityBar => _ActivityBarRegistrar(context);

  @override
  ToolbarRegistrar get toolbar => _ToolbarRegistrar(context);

  @override
  StatusBarRegistrar get statusBar => _StatusBarRegistrar(context);

  @override
  MenuRegistrar get menus => _MenuRegistrar(context);

  @override
  NavigationRegistrar get navigation => _NavigationRegistrar(context);

  @override
  SettingsRegistrar get settings => _SettingsRegistrar(context);

  @override
  WorkspaceModeRegistrar get modes => _WorkspaceModeRegistrar(context);

  @override
  LayoutRegistrar get layouts => _LayoutRegistrar(context);
}

class _ViewRegistrar implements ViewRegistrar {
  final RuntimePluginContext _ctx;
  _ViewRegistrar(this._ctx);
  @override
  void register(ViewContribution view) => _ctx.registerView(view);
}

class _ActivityBarRegistrar implements ActivityBarRegistrar {
  final RuntimePluginContext _ctx;
  _ActivityBarRegistrar(this._ctx);
  @override
  void register(ActivityBarContribution item) =>
      _ctx.registerActivityBarItem(item);
}

class _ToolbarRegistrar implements ToolbarRegistrar {
  final RuntimePluginContext _ctx;
  _ToolbarRegistrar(this._ctx);
  @override
  void register(ToolbarContribution item) => _ctx.registerToolbarItem(item);
}

class _StatusBarRegistrar implements StatusBarRegistrar {
  final RuntimePluginContext _ctx;
  _StatusBarRegistrar(this._ctx);
  @override
  void register(StatusBarContribution item) => _ctx.registerStatusBarItem(item);
}

class _MenuRegistrar implements MenuRegistrar {
  final RuntimePluginContext _ctx;
  _MenuRegistrar(this._ctx);
  @override
  void register(MenuContribution item) => _ctx.registerContextMenuItem(item);
}

class _NavigationRegistrar implements NavigationRegistrar {
  final RuntimePluginContext _ctx;
  _NavigationRegistrar(this._ctx);
  @override
  void register(NavigationContribution item) => _ctx.registerNavigation(item);
  @override
  void registerGroup(NavigationGroup group) =>
      _ctx.runtime.navigation.registerGroup(group);
}

class _SettingsRegistrar implements SettingsRegistrar {
  final RuntimePluginContext _ctx;
  _SettingsRegistrar(this._ctx);
  @override
  void register(SettingsPageContribution page) =>
      _ctx.registerSettingsPage(page);
}

class _WorkspaceModeRegistrar implements WorkspaceModeRegistrar {
  final RuntimePluginContext _ctx;
  _WorkspaceModeRegistrar(this._ctx);
  @override
  void register(WorkspaceMode mode) =>
      _ctx.runtime.workspaceModes.register(mode);
}

class _LayoutRegistrar implements LayoutRegistrar {
  final RuntimePluginContext _ctx;
  _LayoutRegistrar(this._ctx);
  @override
  void register(LayoutPlugin plugin) =>
      _ctx.runtime.layouts.register(plugin);
  @override
  void activate(String layoutPluginId) =>
      _ctx.runtime.layouts.activate(layoutPluginId);
}

class _CommandRegistrar implements CommandRegistrar {
  final RuntimePluginContext _ctx;
  _CommandRegistrar(this._ctx);
  @override
  void register(AppCommand command) => _ctx.registerCommand(command);
}

class _ContextRegistrar implements ContextRegistrar {
  final RuntimePluginContext _ctx;
  _ContextRegistrar(this._ctx);
  @override
  void register(ContextContribution contributor) =>
      _ctx.registerContextContributor(contributor);
}

class _CapabilityService implements CapabilityService {
  final RuntimePluginContext _ctx;
  _CapabilityService(this._ctx);
  @override
  bool supports(String capabilityId) =>
      _ctx.runtime.capabilities.has(capabilityId);
}

class RuntimePluginContext implements PluginContext {
  @override
  final String pluginId;
  final ExtensionRuntime runtime;

  late final ContributionScope contributions = ContributionScope(
    ownerId: pluginId,
  );

  @override
  late final PluginUiApi ui = _RuntimeUiApi(this);

  @override
  late final CommandRegistrar commands = _CommandRegistrar(this);

  @override
  late final ContextRegistrar context = _ContextRegistrar(this);

  @override
  late final CapabilityService capabilities = _CapabilityService(this);

  RuntimePluginContext({required this.pluginId, required this.runtime});

  void registerCommand(AppCommand command) {
    runtime.commands.register(command, ownerId: pluginId);
  }

  void registerView(ViewContribution view) {
    contributions.register(runtime.views, view);
  }

  void registerNavigation(NavigationContribution item) {
    contributions.register(runtime.navigation, item);
  }

  void registerSettingsPage(SettingsPageContribution page) {
    contributions.register(runtime.settings, page);
  }

  void registerContextMenuItem(MenuContribution item) {
    contributions.register(runtime.contextMenus, item);
  }

  void registerToolbarItem(ToolbarContribution item) {
    contributions.register(runtime.toolbar, item);
  }

  void registerStatusBarItem(StatusBarContribution item) {
    contributions.register(runtime.statusBar, item);
  }

  void registerActivityBarItem(ActivityBarContribution item) {
    contributions.register(runtime.activityBar, item);
  }

  void registerContextContributor(ContextContribution contributor) {
    contributions.register(runtime.context, contributor);
  }
}

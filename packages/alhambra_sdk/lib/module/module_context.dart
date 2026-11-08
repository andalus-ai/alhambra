import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class ModuleUiApi implements PluginUiApi {
  final ModuleContext context;
  ModuleUiApi(this.context);

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
}

class _ViewRegistrar implements ViewRegistrar {
  final ModuleContext _ctx;
  _ViewRegistrar(this._ctx);
  @override
  void register(ViewContribution view) => _ctx.registerView(view);
}

class _ActivityBarRegistrar implements ActivityBarRegistrar {
  final ModuleContext _ctx;
  _ActivityBarRegistrar(this._ctx);
  @override
  void register(ActivityBarContribution item) =>
      _ctx.registerActivityBarItem(item);
}

class _ToolbarRegistrar implements ToolbarRegistrar {
  final ModuleContext _ctx;
  _ToolbarRegistrar(this._ctx);
  @override
  void register(ToolbarContribution item) => _ctx.registerToolbarItem(item);
}

class _StatusBarRegistrar implements StatusBarRegistrar {
  final ModuleContext _ctx;
  _StatusBarRegistrar(this._ctx);
  @override
  void register(StatusBarContribution item) => _ctx.registerStatusBarItem(item);
}

class _MenuRegistrar implements MenuRegistrar {
  final ModuleContext _ctx;
  _MenuRegistrar(this._ctx);
  @override
  void register(MenuContribution item) => _ctx.registerContextMenuItem(item);
}

class _NavigationRegistrar implements NavigationRegistrar {
  final ModuleContext _ctx;
  _NavigationRegistrar(this._ctx);
  @override
  void register(NavigationContribution item) => _ctx.registerNavigation(item);
  @override
  void registerGroup(NavigationGroup group) =>
      _ctx.runtime.navigation.registerGroup(group);
}

class _SettingsRegistrar implements SettingsRegistrar {
  final ModuleContext _ctx;
  _SettingsRegistrar(this._ctx);
  @override
  void register(SettingsPageContribution page) =>
      _ctx.registerSettingsPage(page);
}

class _WorkspaceModeRegistrar implements WorkspaceModeRegistrar {
  final ModuleContext _ctx;
  _WorkspaceModeRegistrar(this._ctx);
  @override
  void register(WorkspaceMode mode) =>
      _ctx.runtime.workspaceModes.register(mode);
}

class _CommandRegistrar implements CommandRegistrar {
  final ModuleContext _ctx;
  _CommandRegistrar(this._ctx);
  @override
  void register(AppCommand command) => _ctx.registerCommand(command);
}

class _ContextRegistrar implements ContextRegistrar {
  final ModuleContext _ctx;
  _ContextRegistrar(this._ctx);
  @override
  void register(ContextContribution contributor) =>
      _ctx.registerContextContributor(contributor);
}

class _CapabilityService implements CapabilityService {
  final ModuleContext _ctx;
  _CapabilityService(this._ctx);
  @override
  bool supports(String capabilityId) => _ctx.capabilities.has(capabilityId);
}

class ModuleContext {
  final String moduleId;
  final ExtensionRuntime runtime;

  late final ContributionScope contributions = ContributionScope(
    ownerId: moduleId,
  );

  late final PluginUiApi ui = ModuleUiApi(this);
  late final CommandRegistrar commandsRegistrar = _CommandRegistrar(this);
  late final ContextRegistrar contextRegistrar = _ContextRegistrar(this);
  late final CapabilityService capabilityService = _CapabilityService(this);

  ModuleContext({required this.moduleId, required this.runtime});

  CommandRegistry get commands => runtime.commands;
  ViewRegistry get views => runtime.views;
  NavigationRegistry get navigation => runtime.navigation;
  SettingsRegistry get settings => runtime.settings;
  ContextMenuRegistry get contextMenus => runtime.contextMenus;
  ToolbarRegistry get toolbar => runtime.toolbar;
  StatusBarRegistry get statusBar => runtime.statusBar;
  CapabilityRegistry get capabilities => runtime.capabilities;
  EventBus get events => runtime.events;
  ServiceRegistry get services => runtime.services;
  ToolRegistry get tools => runtime.tools;
  ActivityBarRegistry get activityBar => runtime.activityBar;
  ContextContributorRegistry get contextContributors => runtime.context;
  WorkbenchController get workbench => runtime.workbench;

  void registerCommand(AppCommand command) {
    runtime.commands.register(command, ownerId: moduleId);
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

  void registerCapability(String capabilityId, {String description = ''}) {
    contributions.register(
      runtime.capabilities,
      CapabilityContribution(
        id: capabilityId,
        ownerId: moduleId,
        description: description,
      ),
    );
  }

  void registerService<T>(T service) {
    runtime.services.register<T>(service, ownerId: moduleId);
  }

  void registerTool(AgentTool tool) {
    contributions.register(runtime.tools, tool);
  }

  void registerActivityBarItem(ActivityBarContribution item) {
    contributions.register(runtime.activityBar, item);
  }

  void registerContextContributor(ContextContribution contributor) {
    contributions.register(runtime.context, contributor);
  }
}

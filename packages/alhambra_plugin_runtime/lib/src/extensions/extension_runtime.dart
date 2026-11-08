import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import '../commands/command_registry.dart';
import '../views/view_registry.dart';
import '../navigation/navigation_registry.dart';
import '../settings/settings_registry.dart';
import '../context_menu/context_menu_registry.dart';
import '../toolbar/toolbar_registry.dart';
import '../status_bar/status_bar_registry.dart';
import '../capabilities/capability_registry.dart';
import '../services/service_registry.dart';
import '../tools/tool_registry.dart';
import '../activity_bar/activity_bar_registry.dart';
import '../context/context_contributor_registry.dart';
import '../context/context_service.dart';
import '../workbench/contribution_validator.dart';
import '../workbench/workbench_controller.dart';
import '../workbench/modes/workspace_mode_registry.dart';
import '../workbench/modes/workspace_mode_controller.dart';
import '../workbench/views/in_memory_view_reference_store.dart';
import '../workbench/workbench_view_resolver.dart';
import '../ui/ui_contribution_registry.dart';
import '../ui/ui_surface_resolver.dart';
import '../ui/shell/shell_region_registry.dart';
import '../ui/shell/shell_region_controller.dart';
import '../ui/shell/shell_region_resolver.dart';
import '../composition/composition_runtime.dart';
import '../runtime_scope/runtime_scope_hierarchy.dart';
import '../runtime_scope/scope_disposal_coordinator.dart';
import '../context/incremental_context_engine.dart';
import '../reactivity/signals_engine.dart';
import '../navigation/intent_navigation_engine.dart';
import '../commands/command_interaction_engine.dart';
import '../capabilities/capability_broker.dart';
import '../ui_contributions/ui_contribution_runtime.dart';
import '../transaction/resource_transaction_engine.dart';
import '../layout/declarative_layout_engine.dart';
import '../projection/projection_engine.dart';
import '../packaging/packaging_engine.dart';
import '../discovery/plugin_discovery_manager.dart';
import '../di/service_graph_engine.dart';

class ExtensionRuntime {
  final CommandRegistry commands;
  final ViewRegistry views;
  final NavigationRegistry navigation;
  final SettingsRegistry settings;
  final ContextMenuRegistry contextMenus;
  final ToolbarRegistry toolbar;
  final StatusBarRegistry statusBar;
  final CapabilityRegistry capabilities;
  final EventBus events;
  final ServiceRegistry services;
  final ToolRegistry tools;
  final ActivityBarRegistry activityBar;
  final ContextContributorRegistry context;
  final WorkspaceModeRegistry workspaceModes;
  final LayoutPluginRegistry layouts;
  final ViewReferenceStore viewReferenceStore;
  final UiContributionRegistry uiContributionRegistry;
  final ShellRegionRegistry shellRegionRegistry;
  final ApplicationScope applicationScope;
  final ScopeDisposalCoordinator scopeDisposalCoordinator;
  final ContextStore contextStore;
  final SignalStore signalStore;
  final NavigationHistory navigationHistory;
  final ViewInstanceManager viewInstanceManager;
  final NavigationResolver navigationResolver;
  final DefaultInteractionRegistry interactionRegistry;
  final DefaultExtensionContributionRegistry extensionContributionRegistry;
  final DefaultResourceTransactionManager transactionManager;
  final DefaultDeclarativeLayoutController declarativeLayoutController;
  final LayoutSerializer layoutSerializer;
  final DefaultUiProjectionRegistry uiProjectionRegistry;
  final DefaultPluginTrustStore pluginTrustStore;
  final DefaultPluginSecurityPolicy pluginSecurityPolicy;
  final DefaultPluginPackageVerifier pluginPackageVerifier;
  final InMemoryInstalledPluginStore installedPluginStore;
  final InMemoryPluginCatalog pluginCatalog;
  final DefaultPluginLifecycleManager pluginLifecycleManager;
  final DefaultWorkspaceManager workspaceManager;

  late final WorkspaceModeController workspaceModeController;
  late final ContextService contextService;
  late final ContributionValidator validator;
  late final WorkbenchController workbench;
  late final DefaultUiSurfaceResolver uiSurfaceResolver;
  late final DefaultShellRegionController shellRegionController;
  late final DefaultShellRegionResolver shellRegionResolver;
  late final CompositionRuntime compositionRuntime;
  late final WorkbenchViewResolver viewResolver;
  late final DefaultNavigationService navigationService;
  late final IncrementalContributionResolver contextResolver;
  late final DefaultCommandDispatcher commandDispatcher;
  late final DefaultMenuModelResolver menuModelResolver;
  late final DefaultCapabilityBroker capabilityBroker;
  late final ScopedContributionManager scopedContributionManager;

  ExtensionRuntime({
    CommandRegistry? commands,
    ViewRegistry? views,
    NavigationRegistry? navigation,
    SettingsRegistry? settings,
    ContextMenuRegistry? contextMenus,
    ToolbarRegistry? toolbar,
    StatusBarRegistry? statusBar,
    CapabilityRegistry? capabilities,
    EventBus? events,
    ServiceRegistry? services,
    ToolRegistry? tools,
    ActivityBarRegistry? activityBar,
    ContextContributorRegistry? context,
    WorkspaceModeRegistry? workspaceModes,
    LayoutPluginRegistry? layouts,
    ViewReferenceStore? viewReferenceStore,
    UiContributionRegistry? uiContributionRegistry,
    ShellRegionRegistry? shellRegionRegistry,
    ApplicationScope? applicationScope,
    ScopeDisposalCoordinator? scopeDisposalCoordinator,
    ContextStore? contextStore,
    SignalStore? signalStore,
    NavigationHistory? navigationHistory,
    ViewInstanceManager? viewInstanceManager,
    NavigationResolver? navigationResolver,
    DefaultInteractionRegistry? interactionRegistry,
    DefaultExtensionContributionRegistry? extensionContributionRegistry,
    DefaultResourceTransactionManager? transactionManager,
    DefaultDeclarativeLayoutController? declarativeLayoutController,
    LayoutSerializer? layoutSerializer,
    DefaultUiProjectionRegistry? uiProjectionRegistry,
    DefaultPluginTrustStore? pluginTrustStore,
    PluginSecurityPolicy? pluginSecurityPolicy,
    DefaultPluginPackageVerifier? pluginPackageVerifier,
    InMemoryInstalledPluginStore? installedPluginStore,
    InMemoryPluginCatalog? pluginCatalog,
    DefaultPluginLifecycleManager? pluginLifecycleManager,
    DefaultWorkspaceManager? workspaceManager,
    WorkbenchController? workbench,
  }) : commands = commands ?? CommandRegistry(),
       views = views ?? ViewRegistry(),
       navigation = navigation ?? NavigationRegistry(),
       settings = settings ?? SettingsRegistry(),
       contextMenus = contextMenus ?? ContextMenuRegistry(),
       toolbar = toolbar ?? ToolbarRegistry(),
       statusBar = statusBar ?? StatusBarRegistry(),
       capabilities = capabilities ?? CapabilityRegistry(),
       events = events ?? EventBus(),
       services = services ?? ServiceRegistry(),
       tools = tools ?? ToolRegistry(),
       activityBar = activityBar ?? ActivityBarRegistry(),
       context = context ?? ContextContributorRegistry(),
       workspaceModes = workspaceModes ?? InMemoryWorkspaceModeRegistry(),
       layouts = layouts ?? LayoutPluginRegistry(),
       viewReferenceStore = viewReferenceStore ?? InMemoryViewReferenceStore(),
       uiContributionRegistry =
           uiContributionRegistry ?? InMemoryUiContributionRegistry(),
       shellRegionRegistry =
           shellRegionRegistry ?? InMemoryShellRegionRegistry(),
       applicationScope = applicationScope ?? ApplicationScope(),
       scopeDisposalCoordinator =
           scopeDisposalCoordinator ?? ScopeDisposalCoordinator(),
       contextStore = contextStore ?? InMemoryContextStore(),
       signalStore = signalStore ?? InMemorySignalStore(),
       navigationHistory = navigationHistory ?? DefaultNavigationHistory(),
       viewInstanceManager =
           viewInstanceManager ?? DefaultViewInstanceManager(),
       navigationResolver = navigationResolver ?? DefaultNavigationResolver(),
       interactionRegistry =
           interactionRegistry ?? DefaultInteractionRegistry(),
       extensionContributionRegistry =
           extensionContributionRegistry ??
           DefaultExtensionContributionRegistry(),
       transactionManager =
           transactionManager ?? DefaultResourceTransactionManager(),
       declarativeLayoutController =
           declarativeLayoutController ?? DefaultDeclarativeLayoutController(),
       layoutSerializer = layoutSerializer ?? LayoutSerializer(),
       uiProjectionRegistry =
           uiProjectionRegistry ?? DefaultUiProjectionRegistry(),
       pluginTrustStore = pluginTrustStore ?? DefaultPluginTrustStore(),
       pluginSecurityPolicy =
           (pluginSecurityPolicy as DefaultPluginSecurityPolicy?) ??
           const DefaultPluginSecurityPolicy(),
       pluginPackageVerifier =
           pluginPackageVerifier ??
           DefaultPluginPackageVerifier(
             trustStore: pluginTrustStore ?? DefaultPluginTrustStore(),
             securityPolicy:
                 pluginSecurityPolicy ?? const DefaultPluginSecurityPolicy(),
           ),
       installedPluginStore =
           installedPluginStore ?? InMemoryInstalledPluginStore(),
       pluginCatalog = pluginCatalog ?? InMemoryPluginCatalog(),
       pluginLifecycleManager =
           pluginLifecycleManager ??
           DefaultPluginLifecycleManager(
             verifier:
                 pluginPackageVerifier ??
                 DefaultPluginPackageVerifier(
                   trustStore: pluginTrustStore ?? DefaultPluginTrustStore(),
                   securityPolicy:
                       pluginSecurityPolicy ??
                       const DefaultPluginSecurityPolicy(),
                 ),
             dependencyResolver: DefaultPluginDependencyResolver(
               catalog: pluginCatalog ?? InMemoryPluginCatalog(),
             ),
             store: installedPluginStore ?? InMemoryInstalledPluginStore(),
           ),
       workspaceManager = workspaceManager ?? DefaultWorkspaceManager() {
    contextService = ContextService(registry: this.context);
    validator = ContributionValidator(
      views: this.views,
      activityBar: this.activityBar,
    );
    this.workbench = workbench ?? WorkbenchController(views: this.views);
    workspaceModeController = WorkspaceModeController(
      registry: this.workspaceModes,
      workbench: this.workbench,
    );

    uiSurfaceResolver = DefaultUiSurfaceResolver(
      registry: this.uiContributionRegistry,
    );
    shellRegionController = DefaultShellRegionController(
      registry: this.shellRegionRegistry,
    );
    shellRegionResolver = DefaultShellRegionResolver(
      registry: this.shellRegionRegistry,
      controller: shellRegionController,
    );

    viewResolver = WorkbenchViewResolver(
      viewRegistry: this.views,
      referenceStore: this.viewReferenceStore,
    );

    compositionRuntime = DefaultCompositionRuntime(
      onOwnerDeactivated: (ownerId) {
        this.uiContributionRegistry.unregisterOwner(ownerId);
        this.shellRegionRegistry.unregisterOwner(ownerId);
        this.views.unregisterAllForOwner(ownerId);
        this.commands.unregisterAllForOwner(ownerId);
        this.uiProjectionRegistry.removeOwner(ownerId);
      },
    );

    navigationService = DefaultNavigationService(
      resolver: this.navigationResolver,
      instanceManager: this.viewInstanceManager,
      history: this.navigationHistory,
    );

    contextResolver = IncrementalContributionResolver(
      index: ContextDependencyIndex(),
    );

    commandDispatcher = DefaultCommandDispatcher(
      registry: this.interactionRegistry,
    );
    menuModelResolver = DefaultMenuModelResolver(
      registry: this.interactionRegistry,
    );
    capabilityBroker = DefaultCapabilityBroker(
      policyEngine: HierarchicalPolicyEngine(),
    );
    scopedContributionManager = ScopedContributionManager(
      registry: this.extensionContributionRegistry,
    );
  }

  List<OwnerCleanup> get cleanupTargets => [
    commands,
    views,
    navigation,
    settings,
    contextMenus,
    toolbar,
    statusBar,
    capabilities,
    services,
    tools,
    activityBar,
    context,
  ];
}

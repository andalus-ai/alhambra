import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_extension/alhambra_extension.dart';
import '../core/license/license_service.dart';
import '../core/license/pro_plugin_host.dart';
import '../core/plugins/builtin_plugin_loader.dart';

final extensionRuntimeProvider = Provider<ExtensionRuntime>((ref) {
  return ExtensionRuntime();
});

final moduleManagerProvider = Provider<ModuleManager>((ref) {
  final runtime = ref.watch(extensionRuntimeProvider);
  return ModuleManager(runtime: runtime);
});

final pluginManagerProvider = Provider<PluginManager>((ref) {
  final runtime = ref.watch(extensionRuntimeProvider);
  final manager = PluginManager(runtime: runtime);
  // Auto-load built-in community plugins
  BuiltInPluginLoader(pluginManager: manager).loadAll();
  return manager;
});

final injectedProPluginsProvider = Provider<List<AlhambraPlugin>>((ref) {
  return const [];
});

final proPluginHostProvider = Provider<ProPluginHost>((ref) {
  final pluginManager = ref.watch(pluginManagerProvider);
  final licenseInfo = ref.watch(licenseProvider);
  final proPlugins = ref.watch(injectedProPluginsProvider);
  final host = ProPluginHost(
    pluginManager: pluginManager,
    proPlugins: proPlugins,
  );
  // Synchronize with current edition
  host.syncPlugins(licenseInfo.edition);
  return host;
});

final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).commands;
});

final viewRegistryProvider = Provider<ViewRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).views;
});

final navigationRegistryProvider = Provider<NavigationRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).navigation;
});

final settingsRegistryProvider = Provider<SettingsRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).settings;
});

final toolbarRegistryProvider = Provider<ToolbarRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).toolbar;
});

final contextMenuRegistryProvider = Provider<ContextMenuRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).contextMenus;
});

final statusBarRegistryProvider = Provider<StatusBarRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).statusBar;
});

final capabilityRegistryProvider = Provider<CapabilityRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).capabilities;
});

final eventBusProvider = Provider<EventBus>((ref) {
  return ref.watch(extensionRuntimeProvider).events;
});

final serviceRegistryProvider = Provider<ServiceRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).services;
});

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).tools;
});

final activityBarRegistryProvider = Provider<ActivityBarRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).activityBar;
});

final contextServiceProvider = Provider<ContextService>((ref) {
  return ref.watch(extensionRuntimeProvider).contextService;
});

final workbenchControllerProvider = Provider<WorkbenchController>((ref) {
  return ref.watch(extensionRuntimeProvider).workbench;
});

class WorkbenchLayoutNotifier extends Notifier<WorkbenchLayoutState> {
  @override
  WorkbenchLayoutState build() {
    final controller = ref.watch(workbenchControllerProvider);
    controller.onLayoutChanged.listen((state) {
      this.state = state;
    });
    return controller.layout;
  }
}

final workbenchLayoutProvider =
    NotifierProvider<WorkbenchLayoutNotifier, WorkbenchLayoutState>(
  () => WorkbenchLayoutNotifier(),
);

final workspaceModeRegistryProvider = Provider<WorkspaceModeRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).workspaceModes;
});

final workspaceModeControllerProvider =
    Provider<WorkspaceModeController>((ref) {
  return ref.watch(extensionRuntimeProvider).workspaceModeController;
});

class ActiveWorkspaceModeNotifier extends Notifier<WorkspaceMode> {
  @override
  WorkspaceMode build() {
    final controller = ref.watch(workspaceModeControllerProvider);
    controller.onModeChanged.listen((_) {
      state = controller.currentMode;
    });
    return controller.currentMode;
  }
}

final activeWorkspaceModeProvider =
    NotifierProvider<ActiveWorkspaceModeNotifier, WorkspaceMode>(
  () => ActiveWorkspaceModeNotifier(),
);

// UI-06 Providers: View Reference Store, UI Surfaces, Shell Composition, Composition Runtime
final viewReferenceStoreProvider = Provider<ViewReferenceStore>((ref) {
  return ref.watch(extensionRuntimeProvider).viewReferenceStore;
});

final uiContributionRegistryProvider = Provider<UiContributionRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).uiContributionRegistry;
});

final uiSurfaceResolverProvider = Provider<UiSurfaceResolver>((ref) {
  return ref.watch(extensionRuntimeProvider).uiSurfaceResolver;
});

final shellRegionRegistryProvider = Provider<ShellRegionRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).shellRegionRegistry;
});

final shellRegionControllerProvider = Provider<DefaultShellRegionController>((ref) {
  return ref.watch(extensionRuntimeProvider).shellRegionController;
});

class ShellLayoutNotifier extends Notifier<ShellLayoutState> {
  @override
  ShellLayoutState build() {
    final controller = ref.watch(shellRegionControllerProvider);
    controller.stateStream.listen((state) {
      this.state = state;
    });
    return controller.state;
  }
}

final shellLayoutProvider =
    NotifierProvider<ShellLayoutNotifier, ShellLayoutState>(
  () => ShellLayoutNotifier(),
);

final resolvedShellRegionProvider =
    Provider.family<ResolvedShellRegion, String>((ref, regionId) {
  final resolver = ref.watch(extensionRuntimeProvider).shellRegionResolver;
  ref.watch(shellLayoutProvider); // Re-evaluate when shell layout changes
  return resolver.resolve(regionId);
});

final compositionRuntimeProvider = Provider<CompositionRuntime>((ref) {
  return ref.watch(extensionRuntimeProvider).compositionRuntime;
});

// UI-07 / UI-08 / UI-09 Providers
final scopeRegistryProvider = Provider<ScopeRegistry>((ref) {
  return ScopeRegistry();
});

final workbenchSessionRegistryProvider = Provider<WorkbenchSessionRegistry>((ref) {
  return WorkbenchSessionRegistry();
});

final capabilityAuditLogProvider = Provider<CapabilityAuditLog>((ref) {
  return CapabilityAuditLog();
});

final capabilityResolverProvider = Provider<CapabilityResolver>((ref) {
  return const DefaultCapabilityResolver(
    policies: [
      CommunityCapabilityPolicy(),
    ],
  );
});

// Window-scoped Shell Layout Family Notifier
class WindowShellLayoutNotifier extends Notifier<ShellLayoutState> {
  final WindowId? windowId;

  WindowShellLayoutNotifier([this.windowId]);

  @override
  ShellLayoutState build() {
    return const ShellLayoutState();
  }

  void toggleRegion(String regionId) {
    final hidden = Set<String>.from(state.hiddenRegions);
    if (hidden.contains(regionId)) {
      hidden.remove(regionId);
    } else {
      hidden.add(regionId);
    }
    state = state.copyWith(hiddenRegions: hidden);
  }

  void resizeRegion(String regionId, double size) {
    final sizes = Map<String, double>.from(state.regionSizes);
    sizes[regionId] = size;
    state = state.copyWith(regionSizes: sizes);
  }
}

final windowShellLayoutProvider =
    NotifierProvider.family<WindowShellLayoutNotifier, ShellLayoutState, WindowId>(
  (windowId) => WindowShellLayoutNotifier(windowId),
);

// Session-scoped Workbench Layout Family Notifier
class SessionWorkbenchLayoutNotifier extends Notifier<WorkbenchLayoutState> {
  final WorkbenchSessionId? sessionId;

  SessionWorkbenchLayoutNotifier([this.sessionId]);

  @override
  WorkbenchLayoutState build() {
    return WorkbenchLayoutState.empty();
  }

  void updateState(WorkbenchLayoutState newState) {
    state = newState;
  }
}

final sessionWorkbenchLayoutProvider =
    NotifierProvider.family<SessionWorkbenchLayoutNotifier, WorkbenchLayoutState, WorkbenchSessionId>(
  (sessionId) => SessionWorkbenchLayoutNotifier(sessionId),
);

// UI-10: Reactive UI Context & Incremental Resolution
final contextStoreProvider = Provider<ContextStore>((ref) {
  return ref.watch(extensionRuntimeProvider).contextStore;
});

final incrementalContextResolverProvider =
    Provider<IncrementalContributionResolver>((ref) {
  return ref.watch(extensionRuntimeProvider).contextResolver;
});

class ContextSnapshotNotifier extends Notifier<ContextSnapshot> {
  @override
  ContextSnapshot build() {
    final store = ref.watch(contextStoreProvider);
    store.changes().listen((_) {
      state = store.snapshot();
    });
    return store.snapshot();
  }
}

final contextSnapshotProvider =
    NotifierProvider<ContextSnapshotNotifier, ContextSnapshot>(
  () => ContextSnapshotNotifier(),
);

// UI-11: Signals & Event Bus Reactivity
final signalStoreProvider = Provider<SignalStore>((ref) {
  return ref.watch(extensionRuntimeProvider).signalStore;
});

final scopedEventBusProvider = Provider<ScopedEventBus>((ref) {
  return ScopedEventBus();
});

// UI-12: Navigation & Routing Architecture
final navigationServiceProvider = Provider<NavigationService>((ref) {
  return ref.watch(extensionRuntimeProvider).navigationService;
});

final navigationHistoryProvider = Provider<NavigationHistory>((ref) {
  return ref.watch(extensionRuntimeProvider).navigationHistory;
});

final viewInstanceManagerProvider = Provider<ViewInstanceManager>((ref) {
  return ref.watch(extensionRuntimeProvider).viewInstanceManager;
});

// UI-13: Command Interactions & Menus
final interactionRegistryProvider = Provider<DefaultInteractionRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).interactionRegistry;
});

final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  return ref.watch(extensionRuntimeProvider).commandDispatcher;
});

final menuModelResolverProvider = Provider<MenuModelResolver>((ref) {
  return ref.watch(extensionRuntimeProvider).menuModelResolver;
});

// UI-15: Capability Broker & Permission Enforcement
final capabilityBrokerProvider = Provider<CapabilityBroker>((ref) {
  return ref.watch(extensionRuntimeProvider).capabilityBroker;
});

// UI-16: Extension UI Contribution Runtime
final extensionContributionRegistryProvider =
    Provider<DefaultExtensionContributionRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).extensionContributionRegistry;
});

final scopedContributionManagerProvider =
    Provider<ScopedContributionManager>((ref) {
  return ref.watch(extensionRuntimeProvider).scopedContributionManager;
});

// UI-17: Resource Transactions & Collaborative Editing
final resourceTransactionManagerProvider =
    Provider<ResourceTransactionManager>((ref) {
  return ref.watch(extensionRuntimeProvider).transactionManager;
});

// UI-18: Declarative Layout Engine & Layout State
final declarativeLayoutControllerProvider =
    Provider<DefaultDeclarativeLayoutController>((ref) {
  return ref.watch(extensionRuntimeProvider).declarativeLayoutController;
});

final layoutSerializerProvider = Provider<LayoutSerializer>((ref) {
  return ref.watch(extensionRuntimeProvider).layoutSerializer;
});

class DeclarativeLayoutNotifier extends Notifier<DeclarativeLayoutState> {
  @override
  DeclarativeLayoutState build() {
    final controller = ref.watch(declarativeLayoutControllerProvider);
    controller.onStateChanged.listen((newState) {
      state = newState;
    });
    return controller.state;
  }
}

final declarativeLayoutProvider =
    NotifierProvider<DeclarativeLayoutNotifier, DeclarativeLayoutState>(
  () => DeclarativeLayoutNotifier(),
);

// UI-19: UI State Projection & Reactive Rendering
final uiProjectionRegistryProvider = Provider<UiProjectionRegistry>((ref) {
  return ref.watch(extensionRuntimeProvider).uiProjectionRegistry;
});

// UI-20: Plugin Packaging, Verification & Trust Store
final pluginTrustStoreProvider = Provider<PluginTrustStore>((ref) {
  return ref.watch(extensionRuntimeProvider).pluginTrustStore;
});

final pluginPackageVerifierProvider = Provider<PluginPackageVerifier>((ref) {
  return ref.watch(extensionRuntimeProvider).pluginPackageVerifier;
});

final installedPluginStoreProvider = Provider<InstalledPluginStore>((ref) {
  return ref.watch(extensionRuntimeProvider).installedPluginStore;
});

// UI-21: Plugin Manifest, Discovery & Lifecycle Management
final pluginCatalogProvider = Provider<PluginCatalog>((ref) {
  return ref.watch(extensionRuntimeProvider).pluginCatalog;
});

final pluginLifecycleManagerProvider = Provider<PluginLifecycleManager>((ref) {
  return ref.watch(extensionRuntimeProvider).pluginLifecycleManager;
});

// UI-22: Dependency Injection & Service Graph
final workspaceManagerProvider = Provider<WorkspaceManager>((ref) {
  return ref.watch(extensionRuntimeProvider).workspaceManager;
});

final alhambraUIContextProvider = Provider<AlhambraUIContext>((ref) {
  final wsManager = ref.watch(workspaceManagerProvider);
  return AlhambraUIContext(
    profile: const ApplicationProfile(edition: ProductEdition.community),
    workspaceManager: wsManager,
  );
});



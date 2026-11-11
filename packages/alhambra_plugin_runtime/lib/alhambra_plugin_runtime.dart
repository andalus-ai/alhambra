library alhambra_plugin_runtime;

// Core extensions & registries
export 'src/extensions/contribution_registry.dart';
export 'src/extensions/placed_contribution_registry.dart';
export 'src/extensions/contribution_scope.dart';
export 'src/extensions/extension_runtime.dart';

// Specific Registries
export 'src/commands/command_registry.dart';
export 'src/views/view_registry.dart';
export 'src/navigation/navigation_registry.dart';
export 'src/navigation/intent_navigation_engine.dart';
export 'src/settings/settings_registry.dart';
export 'src/toolbar/toolbar_registry.dart';
export 'src/context_menu/context_menu_registry.dart';
export 'src/status_bar/status_bar_registry.dart';
export 'src/capabilities/capability_registry.dart';
export 'src/capabilities/capability.dart';
export 'src/capabilities/capability_engine.dart';
export 'src/capabilities/capability_guards.dart';
export 'src/services/service_registry.dart';
export 'src/tools/tool_registry.dart';
export 'src/activity_bar/activity_bar_registry.dart';
export 'src/context/context_contributor_registry.dart';
export 'src/context/context_service.dart';
export 'src/context/incremental_context_engine.dart';

export 'src/capabilities/plugin_capability_negotiator.dart';

// Reactivity & Signals
export 'src/reactivity/signals_engine.dart';

// Plugins & Startup Pipeline
export 'src/plugins/plugin_lifecycle_checkpoint.dart';
export 'src/plugins/plugin_runtime_health.dart';
export 'src/plugins/plugin_runtime_reconciler.dart';
export 'src/plugins/plugin_manager.dart';
export 'src/plugins/plugin_loader.dart';
export 'src/plugins/extension_manifest.dart';
export 'src/plugins/plugin_dependency_resolver.dart';
export 'src/plugins/runtime_plugin_context.dart';
export 'src/plugins/plugin_startup_pipeline.dart';
export 'src/plugins/plugin_shutdown_coordinator.dart';
export 'src/plugins/plugin_startup_coordinator.dart';

// Workbench & Layout
export 'src/workbench/contribution_validator.dart';
export 'src/workbench/plugin_cleanup_phase.dart';
export 'src/workbench/view_location.dart';
export 'src/workbench/workbench_layout_resolver.dart';
export 'src/workbench/workbench_layout_state.dart';
export 'src/workbench/workbench_controller.dart';
export 'src/workbench/resolved_view.dart';
export 'src/workbench/view_error_boundary.dart';
export 'src/workbench/workbench_view_resolver.dart';
export 'src/workbench/views/in_memory_view_reference_store.dart';
export 'src/workbench/views/workbench_layout_reconciler.dart';

// Layout subsystem
export 'src/workbench/layout/pane_id.dart';
export 'src/workbench/layout/pane_state.dart';
export 'src/workbench/layout/workbench_pane.dart';
export 'src/workbench/layout/view_group_id.dart';
export 'src/workbench/layout/view_group_state.dart';
export 'src/workbench/layout/workbench_group_resolver.dart';
export 'src/workbench/layout/workbench_layout_policy.dart';
export 'src/workbench/layout/layout_persistence_service.dart';
export 'src/workbench/layout/tree/split_direction.dart';
export 'src/workbench/layout/tree/layout_node.dart';
export 'src/workbench/layout/tree/layout_tree_editor.dart';
export 'src/workbench/layout/tree/layout_tree_navigator.dart';
export 'src/workbench/layout/tree/workbench_layout_validator.dart';
export 'src/workbench/layout/workbench_region.dart';

// Workspace Modes
export 'src/workbench/modes/core_workspace_modes.dart';
export 'src/workbench/modes/workspace_mode_registry.dart';
export 'src/workbench/modes/workspace_mode_controller.dart';

// UI Extension Surfaces
export 'src/ui/ui_contribution_registry.dart';
export 'src/ui/ui_contribution_policy.dart';
export 'src/ui/ui_surface_resolver.dart';

// Shell Composition
export 'src/ui/shell/shell_region_registry.dart';
export 'src/ui/shell/shell_region_controller.dart';
export 'src/ui/shell/shell_region_resolver.dart';

// UI Composition Runtime & Dependency Graph
export 'src/composition/composition_graph.dart';
export 'src/composition/composition_plan.dart';
export 'src/composition/composition_transaction.dart';
export 'src/composition/composition_runtime.dart';
export 'src/composition/composition_lifecycle_event_journal.dart';
export 'src/composition/composition_lifecycle_event_codec.dart';
export 'src/composition/composition_lifecycle.dart';
export 'src/composition/composition_plan_diff.dart';
export 'src/composition/composition_reconciler.dart';
export 'src/composition/composition_persistence.dart';
export 'src/composition/composition_snapshot_migrator.dart';
export 'src/composition/composition_compatibility.dart';

// State Scope & Service Boundaries
export 'src/runtime_scope/scoped_service_registry.dart';
export 'src/runtime_scope/runtime_scope_hierarchy.dart';
export 'src/runtime_scope/scope_disposal_coordinator.dart';
export 'src/runtime_scope/scope_registry.dart';

// Command Interactions, Manifests, Capability Broker & UI Contribution Engines (UI 13-16)
export 'src/commands/command_interaction_engine.dart';
export 'src/manifest/manifest_resolver.dart';
export 'src/capabilities/capability_broker.dart';
export 'src/ui_contributions/ui_contribution_runtime.dart';

// Resource Transactions & Declarative Layout Engine (UI 17-18)
export 'src/transaction/resource_transaction_engine.dart';
export 'src/layout/declarative_layout_engine.dart';

// UI State Projection, Packaging, Discovery & Service Graph (UI 19-22)
export 'src/projection/projection_engine.dart';
export 'src/packaging/packaging_engine.dart';
export 'src/discovery/plugin_discovery_manager.dart';
export 'src/di/service_graph_engine.dart';

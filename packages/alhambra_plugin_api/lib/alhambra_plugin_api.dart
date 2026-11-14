/// Alhambra Plugin API - Public contracts and contribution models.
library alhambra_plugin_api;

export 'package:alhambra_core/alhambra_core.dart' hide WorkspaceId;

export 'plugin_api/ui/ui_surface.dart';
export 'plugin_api/ui/ui_location.dart';
export 'plugin_api/ui/ui_contribution.dart';

export 'plugin_api/extensions/contribution.dart';
export 'plugin_api/extensions/contribution_ordering.dart';
export 'plugin_api/extensions/placed_contribution.dart';

export 'plugin_api/context/context_key.dart';
export 'plugin_api/context/contribution_context.dart';
export 'plugin_api/context/context_builder.dart';
export 'plugin_api/context/context_contributor.dart';
export 'plugin_api/context/reactive_context_contracts.dart';

export 'plugin_api/activity_bar/activity_bar_section.dart';
export 'plugin_api/activity_bar/activity_bar_contribution.dart';

export 'plugin_api/commands/app_command.dart';
export 'plugin_api/commands/command_context.dart';

export 'plugin_api/context_menu/menu_target.dart';
export 'plugin_api/context_menu/menu_context.dart';
export 'plugin_api/context_menu/context_menu_contribution.dart';

export 'plugin_api/events/core_events.dart';
export 'plugin_api/events/event_bus.dart';

export 'plugin_api/navigation/navigation_group.dart';
export 'plugin_api/navigation/navigation_contribution.dart';
export 'plugin_api/navigation/navigation_contracts.dart';

export 'plugin_api/plugins/plugin_metadata.dart';
export 'plugin_api/plugins/plugin_context.dart';
export 'plugin_api/plugins/alhambra_plugin.dart';
export 'plugin_api/plugins/plugin_sdk_contracts.dart';

export 'plugin_api/settings/settings_contribution.dart';

export 'plugin_api/status_bar/status_bar_alignment.dart';
export 'plugin_api/status_bar/status_bar_context.dart';
export 'plugin_api/status_bar/status_bar_contribution.dart';

export 'plugin_api/toolbar/toolbar_alignment.dart';
export 'plugin_api/toolbar/toolbar_context.dart';
export 'plugin_api/toolbar/toolbar_contribution.dart';

export 'plugin_api/tools/agent_tool.dart';

export 'plugin_api/views/ui_region.dart';
export 'plugin_api/views/view_area.dart';
export 'plugin_api/views/view_placement.dart';
export 'plugin_api/views/view_behavior.dart';
export 'plugin_api/views/view_descriptor.dart';
export 'plugin_api/views/view_availability.dart';
export 'plugin_api/views/persisted_view_reference.dart';
export 'plugin_api/views/view_contribution.dart';

export 'plugin_api/workbench/workspace_mode.dart';
export 'plugin_api/workbench/layout_repair.dart';

export 'plugin_api/shell/shell_region_contracts.dart';
export 'plugin_api/composition/composition_contracts.dart';
export 'plugin_api/composition/composition_lifecycle_event_store.dart';
export 'plugin_api/composition/composition_lifecycle_observability.dart';
export 'plugin_api/runtime_scope/runtime_scope_contracts.dart';
export 'plugin_api/capabilities/capabilities_models.dart';
export 'plugin_api/reactivity/signals_contracts.dart';
export 'plugin_api/commands/command_interaction_contracts.dart';
export 'plugin_api/manifest/manifest_models.dart';
export 'plugin_api/capabilities/capability_broker_contracts.dart';
export 'plugin_api/ui_contributions/ui_contribution_contracts.dart';
export 'plugin_api/transaction/transaction_contracts.dart';
export 'plugin_api/layout/declarative_layout_contracts.dart';
export 'plugin_api/layout/layout_plugin_contracts.dart';
export 'plugin_api/layout/application_profile.dart';

// UI State Projection, Packaging, Discovery & Service Graph (UI 19-22)
export 'plugin_api/projection/projection_contracts.dart';
export 'plugin_api/packaging/packaging_contracts.dart';
export 'plugin_api/discovery/discovery_contracts.dart';
export 'plugin_api/di/service_graph_contracts.dart';
export 'plugin_api/packaging/integrity_contracts.dart';

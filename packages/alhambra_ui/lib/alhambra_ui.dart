/// Alhambra UI — application shell, responsive layouts, components,
/// design tokens, and workspace UI infrastructure for the Alhambra Platform.
library;

// Theme & Tokens
export 'src/theme/spacing.dart';
export 'src/theme/dimensions.dart';
export 'src/theme/color_scheme.dart';
export 'src/theme/typography.dart';
export 'src/theme/alhambra_theme.dart';

// Layout
export 'src/layout/responsive_layout.dart';
export 'src/layout/adaptive_scaffold.dart';
export 'src/layout/split_view.dart';
export 'src/layout/detail_layout.dart';

// Navigation
export 'src/navigation/navigation_item.dart';
export 'src/navigation/navigation_section.dart';
export 'src/navigation/navigation_registry.dart';
export 'src/navigation/navigation_service.dart';

// Routing
export 'src/routing/route_definition.dart';
export 'src/routing/route_guard.dart';
export 'src/routing/route_registry.dart';

// Shell
export 'src/shell/shell_state.dart';
export 'src/shell/shell_config.dart';
export 'src/shell/shell_controller.dart';
export 'src/shell/app_shell.dart';

// States
export 'src/states/loading_state.dart';
export 'src/states/empty_state.dart';
export 'src/states/error_state.dart';
export 'src/states/unauthorized_state.dart';

// Authorization
export 'src/authorization/authorized.dart';
export 'src/authorization/permission_gate.dart';
export 'src/authorization/role_visibility.dart';

// Workspace
export 'src/workspace/workspace_header.dart';
export 'src/workspace/workspace_navigation.dart';
export 'src/workspace/workspace_shell.dart';
export 'src/workspace/workspace_context.dart';

// P13: View State (4-dimension model)
export 'src/view_state/view_state.dart';

// P13: Organization
export 'src/organization/organization_context.dart';
export 'src/organization/organization_switcher.dart';

// P13: Sync Widgets
export 'src/sync/sync_widgets.dart';

// P13: Action Availability
export 'src/actions/ui_action_state.dart';

// P13: Error Classification
export 'src/errors/ui_error.dart';

// Feedback
export 'src/feedback/notification_surface.dart';
export 'src/feedback/toast.dart';
export 'src/feedback/progress.dart';

// Search
export 'src/search/search_field.dart';
export 'src/search/search_results.dart';
export 'src/search/search_overlay.dart';

// Components
export 'src/components/buttons/alhambra_button.dart';
export 'src/components/cards/alhambra_card.dart';
export 'src/components/forms/alhambra_text_field.dart';
export 'src/components/tables/alhambra_data_table.dart';
export 'src/components/dialogs/alhambra_dialog.dart';
export 'src/components/badges/alhambra_badge.dart';

// App
export 'src/app/app_environment.dart';
export 'src/app/app_config.dart';
export 'src/app/alhambra_app.dart';

// A2UI — Dynamic Intelligence UI (P13 foundation + P14 extensions)
export 'src/a2ui/ui_node.dart';
export 'src/a2ui/ui_action.dart';
export 'src/a2ui/ui_surface.dart';
export 'src/a2ui/ui_renderer.dart';
export 'src/a2ui/a2ui_codec.dart';
export 'src/a2ui/a2ui_action_guard.dart';
export 'src/a2ui/intelligence_result_surface.dart';

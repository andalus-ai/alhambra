/// Built-in layout plugins for the Alhambra platform.
///
/// Exports five ready-to-use [LayoutPlugin] implementations:
///
/// | Plugin                     | Best for                              |
/// |---------------------------|---------------------------------------|
/// | [WorkbenchLayout]         | IDE / code editors (large screens)    |
/// | [CodingAgentLayout]       | AI coding-agent: chat + code + terminal|
/// | [DashboardLayout]         | Data dashboards, analytics panels     |
/// | [MobileLayout]            | Mobile-first apps with bottom nav     |
/// | [MinimalDesktopLayout]    | Simple desktop utilities              |
library;

export 'workbench_layout.dart';
export 'coding_agent_layout.dart';
export 'dashboard_layout.dart';
export 'mobile_layout.dart';
export 'minimal_desktop_layout.dart';
export 'layout_plugin_host.dart';

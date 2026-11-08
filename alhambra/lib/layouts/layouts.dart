/// Generic built-in layout plugins for Alhambra adopters.
///
/// Product-specific compositions are intentionally excluded from this barrel.
/// Import a feature-owned layout directly when an application explicitly opts
/// into it. In particular, coding-agent composition belongs in Cifr UI.
library;

export 'workbench_layout.dart';
export 'dashboard_layout.dart';
export 'mobile_layout.dart';
export 'minimal_desktop_layout.dart';
export 'layout_plugin_host.dart';

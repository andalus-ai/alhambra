/// Stable UI extension surface identifiers for Alhambra workbench.
abstract final class UiSurfaces {
  static const activityBar = 'alhambra.ui.activityBar';
  static const globalToolbar = 'alhambra.ui.globalToolbar';
  static const statusBarLeft = 'alhambra.ui.statusBar.left';
  static const statusBarRight = 'alhambra.ui.statusBar.right';
  static const viewToolbar = 'alhambra.ui.viewToolbar';
  static const tabContextMenu = 'alhambra.ui.tabContextMenu';
  static const commandPalette = 'alhambra.ui.commandPalette';
  static const emptyState = 'alhambra.ui.emptyState';
  static const regionHeader = 'alhambra.ui.regionHeader';
}

/// Kinds of UI surfaces.
enum UiSurfaceKind {
  toolbar,
  menu,
  activityBar,
  statusBar,
  widget,
  command,
}

/// Definition of an extensible UI surface.
class UiSurfaceDefinition {
  final String id;
  final UiSurfaceKind kind;
  final bool allowThirdParty;

  const UiSurfaceDefinition({
    required this.id,
    required this.kind,
    this.allowThirdParty = true,
  });
}

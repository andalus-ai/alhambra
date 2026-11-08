import 'package:flutter/widgets.dart';
import 'application_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen classification
// ─────────────────────────────────────────────────────────────────────────────

/// The three-tier screen-size classification used by the platform layout
/// system.
///
/// Determined from **available widget constraints**, never from device type.
///
/// | Tier    | Width          | Typical form factor                  |
/// |---------|---------------|--------------------------------------|
/// | small   | < 600 dp      | Phone / narrow window                |
/// | medium  | 600–1024 dp   | Tablet / split-screen / landscape    |
/// | large   | ≥ 1024 dp     | Desktop / laptop / large tablet      |
enum ScreenClass {
  /// Narrow single-column layout — only main content visible.
  small,

  /// Intermediate layout — sidebar available as a rail or drawer.
  medium,

  /// Full workbench layout — all panels visible simultaneously.
  large,
}

// ─────────────────────────────────────────────────────────────────────────────
// Application-type hint
// ─────────────────────────────────────────────────────────────────────────────

/// Semantic category of the host application.
///
/// [LayoutPlugin] implementations receive this as a hint so that a single
/// plugin can adjust its behaviour (e.g. hiding a terminal pane in a
/// dashboard app).
@Deprecated('Use ApplicationProfile and LayoutProfileRequirements.')
enum AppKind {
  /// Classic multi-pane IDE / code-editor shell.
  ide,

  /// Autonomous AI coding-agent interface (chat + diff + terminal).
  codingAgent,

  /// Data-oriented dashboard with cards, charts, and stats widgets.
  dashboard,

  /// Standard mobile-first application (bottom-nav, drawers, sheets).
  mobile,

  /// Minimal desktop application without complex pane management.
  desktop,

  /// Custom / unknown — defer all decisions to the plugin.
  custom,
}

// ─────────────────────────────────────────────────────────────────────────────
// Metadata
// ─────────────────────────────────────────────────────────────────────────────

/// Declarative metadata about a [LayoutPlugin].
///
/// Displayed in the layout picker UI and used by the registry for lookup.
class LayoutPluginMetadata {
  /// Unique identifier, e.g. `'alhambra.layout.workbench'`.
  final String id;

  /// Human-readable name shown in layout pickers.
  final String name;

  /// Short description of what this layout provides.
  final String description;

  /// Icon shown next to the name in the picker.
  final IconData icon;

  /// Optional tags for filtering, e.g. `['ide', 'desktop']`.
  final List<String> tags;

  /// Legacy application categories. Prefer [profileRequirements].
  @Deprecated('Use profileRequirements for new layout integrations.')
  final Set<AppKind> suitableFor;

  /// Open capability requirements and preference hints for host applications.
  final LayoutProfileRequirements profileRequirements;

  /// Whether this layout can run in the supplied host application profile.
  bool isCompatibleWith(ApplicationProfile profile) =>
      profileRequirements.isCompatibleWith(profile);

  /// Preference score used to rank compatible layouts for a host profile.
  int preferenceScore(ApplicationProfile profile) =>
      profileRequirements.preferenceScore(profile);

  const LayoutPluginMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.tags = const [],
    this.suitableFor = const {AppKind.custom},
    this.profileRequirements = const LayoutProfileRequirements(),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Named identifiers for the standard layout slots.
///
/// Platform adopters or mode contributions may supply custom builders for any
/// slot via [LayoutSlotConfig]. Unknown slot IDs are ignored gracefully.
abstract final class LayoutSlot {
  static const String activityBar = 'activityBar';
  static const String sidebar = 'sidebar';
  static const String mainContent = 'mainContent';
  static const String bottomPanel = 'bottomPanel';
  static const String secondaryPanel = 'secondaryPanel';
  static const String toolbar = 'toolbar';
  static const String statusBar = 'statusBar';
}

/// A map of [LayoutSlot] id → optional [WidgetBuilder] overrides.
///
/// `null` values mean "use the plugin's default for this slot".
///
/// ```dart
/// final config = LayoutSlotConfig({
///   LayoutSlot.sidebar: (ctx) => MyProjectExplorer(),
///   LayoutSlot.activityBar: (ctx) => MyBrandedBar(),
/// });
/// ```
class LayoutSlotConfig {
  final Map<String, WidgetBuilder?> _overrides;

  const LayoutSlotConfig([this._overrides = const {}]);

  /// Returns the override builder for [slotId], or `null` if not set.
  WidgetBuilder? override(String slotId) => _overrides[slotId];

  /// Returns `true` when an override exists for [slotId].
  bool has(String slotId) => _overrides.containsKey(slotId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout plugin interface
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract base for all layout plugins.
///
/// A layout plugin is responsible for assembling the root widget tree that
/// fills the main application area for a given [ScreenClass].
///
/// ## Minimal implementation
///
/// ```dart
/// class MySimpleLayout extends LayoutPlugin {
///   const MySimpleLayout();
///
///   @override
///   LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
///     id: 'com.example.my_layout',
///     name: 'My Layout',
///     description: 'A simple single-column layout',
///     icon: Icons.view_agenda,
///     suitableFor: {AppKind.mobile},
///   );
///
///   @override
///   Widget build(
///     BuildContext context, {
///     required ScreenClass screenClass,
///     required AppKind appKind,
///     required LayoutSlotConfig slots,
///   }) {
///     return const Center(child: Text('My content'));
///   }
/// }
/// ```
///
/// ## Slot overrides
///
/// Plugins should check `slots.override(LayoutSlot.sidebar)` before rendering
/// their default sidebar, allowing adopters to inject custom widgets.
abstract class LayoutPlugin {
  const LayoutPlugin();

  /// Metadata exposed in the layout registry / picker.
  LayoutPluginMetadata get metadata;

  /// Builds the root widget for the given [screenClass] and [appKind].
  ///
  /// * [screenClass] — the current viewport tier (small/medium/large).
  /// * [appKind] — the semantic application category provided by the host app.
  /// * [slots] — per-slot widget builder overrides contributed by the
  ///   platform adopter or the active workspace mode.
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    throw UnsupportedError(
      'A layout must implement build or ProfileAwareLayoutPlugin.buildForProfile.',
    );
  }

  /// Called when the plugin is registered. May be overridden for one-time
  /// initialization (e.g. registering commands).
  void onRegistered() {}

  /// Called when the plugin is unregistered / disposed.
  void onUnregistered() {}
}

/// Optional open-profile build contract for new layout implementations.
///
/// Legacy [LayoutPlugin] implementations may continue overriding [LayoutPlugin.build].
/// New layouts can implement this interface and receive the full host profile
/// without depending on the closed [AppKind] taxonomy.
abstract interface class ProfileAwareLayoutPlugin {
  Widget buildForProfile(
    BuildContext context, {
    required ScreenClass screenClass,
    required ApplicationProfile applicationProfile,
    required LayoutSlotConfig slots,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

/// Registry that holds all contributed [LayoutPlugin]s.
///
/// The platform maintains a single global registry exposed via Riverpod
/// (see `layoutPluginRegistryProvider` in the app layer).
///
/// ### Registration (from a plugin's `activate` method)
///
/// ```dart
/// context.layouts.register(MyLayout());
/// ```
///
/// ### Selection (from the app entry-point or a settings UI)
///
/// ```dart
/// registry.activate('com.example.my_layout');
/// ```
class LayoutPluginRegistry {
  final Map<String, LayoutPlugin> _plugins = {};
  String? _activeId;

  /// All registered layout plugins.
  Iterable<LayoutPlugin> get all => _plugins.values;

  /// Metadata of all registered plugins.
  Iterable<LayoutPluginMetadata> get allMetadata =>
      _plugins.values.map((p) => p.metadata);

  /// The currently active layout plugin.
  LayoutPlugin? get active =>
      _activeId != null ? _plugins[_activeId] : _plugins.values.firstOrNull;

  /// Registers [plugin] and calls [LayoutPlugin.onRegistered].
  ///
  /// If a plugin with the same [LayoutPluginMetadata.id] is already registered
  /// it is silently replaced.
  void register(LayoutPlugin plugin) {
    _plugins[plugin.metadata.id] = plugin;
    plugin.onRegistered();
  }

  /// Activates the plugin with [id].
  ///
  /// Throws [StateError] if no plugin with that id is registered.
  void activate(String id) {
    if (!_plugins.containsKey(id)) {
      throw StateError('LayoutPlugin "$id" is not registered.');
    }
    _activeId = id;
  }

  /// Looks up a plugin by id. Returns `null` if not found.
  LayoutPlugin? find(String id) => _plugins[id];

  /// Unregisters the plugin with [id] and calls [LayoutPlugin.onUnregistered].
  void unregister(String id) {
    final plugin = _plugins.remove(id);
    plugin?.onUnregistered();
    if (_activeId == id) _activeId = null;
  }
}

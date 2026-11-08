# Alhambra Platform — Responsive & Pluggable Layout Architecture

This document describes the generic, agnostic layout architecture of **Alhambra Platform** (`Projects/Andalus-Agents/Alhambra/Platform`), how it supports responsive layouts across **small**, **medium**, and **large** screens, and how developers implementing custom applications (such as the **Aljabr** coding agent, IDEs, dashboards, mobile apps, and desktop utilities) can easily extend or contribute layouts.

---

## 1. Architectural Overview

Alhambra Platform decouples the platform shell from any single layout topology. Layouts are treated as **first-class pluggable components** via the `LayoutPlugin` contract in `alhambra_plugin_api`.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Alhambra Application Host                       │
│                        (MainHomeScreen / Riverpod)                     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           LayoutPluginHost                             │
│       • Measures constraints via LayoutBuilder                         │
│       • Determines ScreenClass: small (<600dp), medium, large (≥1024dp)│
│       • Injects PlatformScreenClass InheritedWidget into widget tree   │
│       • Delegates rendering to the active LayoutPlugin                 │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       ▼                            ▼                            ▼
┌──────────────────┐      ┌──────────────────┐         ┌──────────────────┐
│  WorkbenchLayout │      │CodingAgentLayout │         │ DashboardLayout  │
│  (IDE / 4-Pane)  │      │(Aljabr Pair-Prog)│         │(Analytics/Cards) │
└──────────────────┘      └──────────────────┘         └──────────────────┘
       ▼                            ▼                            ▼
┌──────────────────┐      ┌──────────────────┐         ┌──────────────────┐
│   MobileLayout   │      │MinimalDesktop    │         │ Custom Plugins   │
│  (Bottom Nav)    │      │ (Utility/Prefs)  │         │ (contributed)    │
└──────────────────┘      └──────────────────┘         └──────────────────┘
```

---

## 2. Core Contracts (`alhambra_plugin_api`)

### 2.1 `ScreenClass` (Constraint-Driven Responsiveness)

Layout decisions are based on **available widget space** (`BoxConstraints.maxWidth`) rather than device types or hardware checks:

| ScreenClass | Available Width | Description & Typical Behavior |
| :--- | :--- | :--- |
| `ScreenClass.small` | `< 600 dp` | Single-column view; sidebars and navigation move into drawers or bottom bars. |
| `ScreenClass.medium` | `600 – 1024 dp` | Two-column / rail view; secondary panel collapses into overlay or modal sheet. |
| `ScreenClass.large` | `≥ 1024 dp` | Full multi-column view; sidebar, editor area, terminal, and secondary drawer visible simultaneously. |

Contributed child views can inspect the current tier anywhere down the widget tree:

```dart
final screen = PlatformScreenClass.of(context);
if (screen == ScreenClass.small) {
  return const CompactChatCard();
}
return const FullChatPanel();
```

### 2.2 `AppKind` (Application Semantic Category)

A hint provided by the host application so that a layout plugin can adapt its features (e.g. omitting developer terminal panels in a non-developer dashboard):

```dart
enum AppKind {
  ide,          // Multi-pane code editor shell
  codingAgent,  // AI pair-programmer (e.g. Aljabr)
  dashboard,    // Data cards, charts, and table grids
  mobile,       // Mobile-first touch interface
  desktop,      // Utility/desktop shell
  custom,       // Extension/adopter specific
}
```

### 2.3 `LayoutSlotConfig` (Slot Overrides)

Adopters can override any slot widget without subclassing the layout plugin:

```dart
final slots = LayoutSlotConfig({
  LayoutSlot.sidebar: (context) => const MyCustomExplorer(),
  LayoutSlot.mainContent: (context) => const MyCustomWorkspace(),
  LayoutSlot.secondaryPanel: (context) => const MyAssistantPanel(),
  LayoutSlot.bottomPanel: (context) => const MyTerminalPanel(),
  LayoutSlot.activityBar: (context) => const MyBrandedRail(),
});
```

---

## 3. Built-In Layout Plugins

The platform includes 5 production-ready layouts in `alhambra/lib/layouts/`:

### 3.1 `WorkbenchLayout` (`alhambra.layout.workbench`)
* **Best for:** IDEs, developer workstations.
* **Large:** 4-column shell: `ActivityBar | Sidebar | Main + Bottom | Secondary`.
* **Medium:** 3-column shell: `ActivityBar | Sidebar | Main + Bottom` (secondary hidden/toggleable).
* **Small:** Full-screen `Main + Bottom` with a bottom navigation bar and slide-out `Drawer` for the sidebar.

### 3.2 `CodingAgentLayout` (`alhambra.layout.coding_agent`)
* **Best for:** Autonomous coding agents like **Aljabr** (`Projects/Andalus-Agents/Aljabr/Community/UI`).
* **Large:** Side-by-side: Agent Chat / Thought Stream (60%) on the left, Code / Diff Viewer (40%) on the right, Terminal / Diagnostic panel docked at the bottom.
* **Medium:** Full-width agent conversation with bottom terminal; diff inspector accessible as an overlay.
* **Small:** Full-screen chat interface; terminal and diff accessible via modal bottom sheets.

### 3.3 `DashboardLayout` (`alhambra.layout.dashboard`)
* **Best for:** Analytics dashboards, admin consoles, telemetry panels.
* **Large:** Permanent 240dp navigation sidebar + expanded card/chart grid.
* **Medium:** Collapsed 72dp icon rail + expanded card/chart grid.
* **Small:** Full-screen cards + hamburger drawer for navigation.

### 3.4 `MobileLayout` (`alhambra.layout.mobile`)
* **Best for:** Mobile apps, PWAs, compact tablets.
* **Large:** Left navigation rail (80dp) + centred content constrained to readable max-width (900dp).
* **Medium / Small:** Full-width content with bottom `NavigationBar`.

### 3.5 `MinimalDesktopLayout` (`alhambra.layout.minimal_desktop`)
* **Best for:** Preferences windows, setup wizards, lightweight utilities.
* **All sizes:** Single centred column with adaptive `maxWidth` (480dp on small, 720dp on medium, 1024dp on large).

---

## 4. How Developers Can Implement & Extend

### 4.1 Creating a Custom Layout Plugin

Implement the `LayoutPlugin` abstract class:

```dart
import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class MyWorkflowCanvasLayout extends LayoutPlugin {
  const MyWorkflowCanvasLayout();

  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
    id: 'com.mycompany.layout.canvas',
    name: 'Workflow Canvas',
    description: 'Node graph canvas layout with floating toolbar',
    icon: Icons.account_tree_outlined,
    suitableFor: {AppKind.custom, AppKind.desktop},
  );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    // 1. Honor slot overrides
    final main = slots.override(LayoutSlot.mainContent)?.call(context)
        ?? const Center(child: Text('Canvas Area'));

    // 2. Adapt layout to screenClass
    if (screenClass == ScreenClass.small) {
      return Scaffold(
        body: main,
        floatingActionButton: const FloatingActionButton(
          onPressed: null,
          child: Icon(Icons.add),
        ),
      );
    }

    return Row(
      children: [
        if (slots.has(LayoutSlot.sidebar))
          SizedBox(
            width: 260,
            child: slots.override(LayoutSlot.sidebar)!(context),
          ),
        Expanded(child: main),
      ],
    );
  }
}
```

### 4.2 Registering via an `AlhambraPlugin`

Any plugin can register custom layouts during `activate()`:

```dart
class MyPlatformExtensionPlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.mycompany.plugin.ext',
    name: 'Custom Extensions',
    version: '1.0.0',
  );

  @override
  Future<void> activate(PluginContext context) async {
    // Register layout into the platform
    context.ui.layouts.register(const MyWorkflowCanvasLayout());

    // Optionally activate it immediately
    context.ui.layouts.activate('com.mycompany.layout.canvas');
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}
```

### 4.3 Switching Layouts Programmatically

```dart
// Via runtime
runtime.layouts.activate(CodingAgentLayout.id);

// Via Riverpod
ref.read(layoutPluginRegistryProvider).activate(DashboardLayout.id);
```

### 4.4 Customizing Individual Slots

Adopters can override specific slots via Riverpod without writing a new layout plugin:

```dart
final container = ProviderContainer(
  overrides: [
    appKindProvider.overrideWith((ref) => AppKind.codingAgent),
    layoutSlotConfigProvider.overrideWithValue(
      LayoutSlotConfig({
        LayoutSlot.mainContent: (context) => const AljabrChatView(),
        LayoutSlot.secondaryPanel: (context) => const AljabrDiffViewer(),
        LayoutSlot.bottomPanel: (context) => const AljabrTerminalPanel(),
      }),
    ),
  ],
);
```

---

## 5. Verification & Testing

The layout plugin system is verified with unit and widget test suites in `packages/alhambra_plugin_runtime/test/workbench_layout_test.dart` and `packages/alhambra_plugin_api/test/alhambra_plugin_api_test.dart`:

```bash
cd Projects/Andalus-Agents/Alhambra/Platform/packages/alhambra_plugin_api
flutter test

cd ../alhambra_plugin_runtime
flutter test test/workbench_layout_test.dart
```

All 70+ tests across the platform packages run and pass.

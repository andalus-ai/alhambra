# Alhambra Layout Extension Architecture

Alhambra provides responsive layout primitives and an opt-in layout registry.
The foundation is application-neutral: it does not assume that every adopter
is an IDE, coding agent, dashboard, or mobile product.

## Application identity

New integrations should provide an open `ApplicationProfile`:

```dart
const ApplicationProfile(
  applicationId: 'com.example.operations-console',
  capabilities: {
    'ui.shell',
    'ui.navigation',
    'data.tables',
    'data.visualization',
  },
  layoutHints: {'adaptive', 'dense', 'navigation-rail'},
);
```

Capabilities are open string identifiers owned by the application or an
extension namespace. Alhambra must not add a new enum value whenever a new
product category appears. Layout requirements should use hard capability
requirements and optional preference hints:

```dart
const LayoutProfileRequirements(
  requiredCapabilities: {'ui.shell', 'ui.navigation'},
  preferredHints: {'adaptive'},
);
```

A layout is compatible only when all required capabilities are present.
Preferred hints are advisory and may rank compatible layouts; they are not
security or authorization checks. The layout host preserves the explicitly
active layout while it remains compatible. If it becomes incompatible, the
host selects the highest-scoring compatible registered layout and reports a
clear configuration error when no compatible layout exists.

## Registration and tree shaking

The default host registers only broadly reusable layouts: mobile/adaptive
navigation, dashboard composition, and minimal content. Each built-in layout
declares its required capabilities and preferred hints. Workbench and
product-specific layouts are opt-in. An adopter imports and registers only
the layout bundle it needs:

```dart
final registry = LayoutPluginRegistry()
  ..register(const MobileLayout())
  ..register(const MinimalDesktopLayout())
  ..register(const MyWorkflowCanvasLayout());
registry.activate(MyWorkflowCanvasLayout.id);
```

Do not create a universal registry that imports every feature pack. Explicit
registration keeps dependency edges visible to Dart's compiler and allows
unused feature libraries to be tree-shaken.

Flutter applications cannot generally download and execute arbitrary Dart
widget code at runtime. Runtime configuration may select among compiled
contributions or describe declarative UI, but executable extensions must be
compiled into the application or delivered through a supported platform
mechanism.

## Legacy migration

The closed `AppKind` enum remains in the current `LayoutPlugin.build`
signature during migration so existing layout implementations continue to
compile. The host defaults it to `AppKind.custom`, never to an IDE category.
A subsequent API revision will replace this legacy parameter with
`ApplicationProfile` after built-in and adopter layouts have migrated.

## Ownership boundaries

- Alhambra: generic responsive layouts, shell composition, design system,
  extension contracts, and UI primitives.
- Cifr UI: coding-agent-specific chat, editor, diff, terminal, and execution
  workflows. Coding-agent layouts belong in Cifr UI's optional composition.
- Wayang: workflow and low-code studio composition.
- Andalus: agent/runtime/backend semantics, not UI shell assumptions.

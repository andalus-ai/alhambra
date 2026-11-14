# Alhambra Plugin Host Starter

A minimal Flutter host showing how an application constructs a compiled plugin
and activates it through `PluginManager`.

## Run

From this directory:

```sh
flutter pub get
flutter run
```

Run the lifecycle smoke test:

```sh
flutter test
```

## What it demonstrates

- A host-owned plugin instance implementing `AlhambraPlugin`.
- Stable plugin metadata and an owner ID.
- Registration of a command, workbench view and settings page through
  `PluginContext`.
- Host-side activation and orderly deactivation.

The sample app deliberately displays a host-owned status screen. It demonstrates
plugin lifecycle and contribution registration, not a complete workbench
renderer. A host must compose the relevant Alhambra UI surfaces to render
registered contributions.

## Trust boundary

The host imports and constructs the plugin implementation. This is a compiled,
trusted-code example; it does not download, dynamically execute or sandbox
plugin code. Capability compatibility checks are not authorization grants.

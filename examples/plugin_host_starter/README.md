# Alhambra Plugin Host Starter

A minimal Flutter host showing how an application constructs a trusted compiled
plugin and composes startup/shutdown through `PluginHostLifecycle`.

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
- Startup through `PluginStartupCoordinator` delegated by
  `PluginHostLifecycle`.
- Graceful plugin deactivation before host resource disposal.
- Host lifecycle shutdown when the Flutter app detaches or its root widget is
  disposed.

The sample has no external host resources, but demonstrates where resource
disposers are registered. Real hosts should register persistence, HTTP clients,
message consumers, and other resources in dependency order, then let
`PluginHostLifecycle` dispose them in reverse order.

The sample status screen is host-owned. It demonstrates lifecycle and
contribution registration, not a complete workbench renderer. A host must
compose the relevant Alhambra UI surfaces to render registered contributions.

## Trust boundary

The host imports and constructs the plugin implementation. This is a compiled,
trusted-code example; it does not download, dynamically execute or sandbox
plugin code. Capability compatibility checks are not authorization grants.

The host must stop accepting new work and drain in-flight operations before
calling `shutdown()`. Flutter's detached callback is a best-effort example;
production service hosts should connect shutdown to their process supervisor
and enforce their own termination deadline.

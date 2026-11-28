# alhambra_plugin_host

A small, dependency-light host composition package for coordinating Alhambra
plugin startup/shutdown with application-owned resource disposal.

## Responsibilities

- Delegates dependency ordering, plugin activation, and startup rollback to
  `PluginStartupCoordinator`.
- Delegates reverse dependency-order deactivation and per-plugin failure
  aggregation to `PluginShutdownCoordinator`.
- Disposes host resources in reverse registration order, after plugin shutdown.
- Continues disposing independent resources after a disposal failure.
- Preserves resources when shutdown preflight fails, because active plugins may
  still depend on them.

## Bootstrap

The application constructs infrastructure first, then passes its compiled
plugins, discovered manifests, coordinators, and resource disposers to the
host lifecycle object.

```dart
final manager = PluginManager();
final persistence = openApplicationPersistence();
final httpClient = createHttpClient();

final lifecycle = PluginHostLifecycle(
  startupCoordinator: PluginStartupCoordinator(manager: manager),
  shutdownCoordinator: PluginShutdownCoordinator(manager: manager),
  discoveredPlugins: discoveredPlugins,
  compiledPlugins: compiledPlugins,
  resources: [
    PluginHostResource(id: 'persistence', dispose: persistence.close),
    PluginHostResource(id: 'http-client', dispose: httpClient.close),
  ],
);

final startup = await lifecycle.start();
if (!startup.succeeded) {
  // Keep the host unready and surface startup.pluginReport/error.
  return;
}

// On the host's shutdown signal:
final shutdown = await lifecycle.shutdown();
if (!shutdown.succeeded) {
  // Log the plugin and resource failures; do not hide partial shutdown.
}
```

Resources are closed in reverse registration order, so register dependencies
before the resources that depend on them. The host must stop accepting work and
drain in-flight requests before calling `shutdown()`.

## Important behavior

- Startup is one-shot. A failed startup closes registered resources; create a
  new host lifecycle instance for a fresh startup attempt.
- Shutdown is idempotent after successful resource disposal.
- If plugin shutdown preflight fails, no plugin callback is attempted and
  resources remain open. Supply corrected discovery input to a later
  `shutdown(discoveredPlugins: ...)` call.
- If a plugin shutdown hook fails after deactivation is attempted, the runtime
  still performs its documented manager cleanup; remaining plugins are
  attempted and host resources are then disposed. The report remains failed.
- A resource disposer that throws is reported; disposal continues. Successfully
  disposed resources are not disposed a second time. A later explicit
  `shutdown()` call retries only failed disposers; because a thrown disposer may
  have partially completed, retry only when its effect has been inspected or
  the callback is designed to be idempotent. Plugin shutdown is not repeated.
- This package does not own discovery, plugin trust, infrastructure creation,
  process signals, request draining, readiness endpoints, timeouts, backup
  scheduling, or automatic recovery.

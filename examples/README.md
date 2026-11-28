# Alhambra Examples

Runnable and focused examples for application hosts and extension authors.

## Plugin host starter

[`plugin_host_starter/`](plugin_host_starter/README.md) is a minimal Flutter
application that constructs a trusted compiled plugin and uses
`PluginHostLifecycle` to delegate dependency-aware startup/shutdown to the
runtime coordinators.

It is a lifecycle/registration starter, not a complete workbench shell or
dynamic plugin loader.

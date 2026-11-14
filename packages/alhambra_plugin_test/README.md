# Alhambra Plugin Test Utilities

A small test-only support package for exercising plugins through the real
Alhambra PluginManager and ExtensionRuntime.

## Add the package

For in-repository development:

~~~yaml
dev_dependencies:
  alhambra_plugin_test:
    path: ../alhambra_plugin_test
~~~

Import the utilities in tests:

~~~dart
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
~~~

## Test lifecycle and cleanup

~~~dart
final host = AlhambraPluginTestHost();
final before = host.snapshot();

await host.activate(MyPlugin());

expect(host.isActive('my.plugin'), isTrue);
expect(host.snapshot().differenceFrom(before)['commands'], 1);

await host.deactivate('my.plugin');
expect(host.snapshot().hasSameCountsAs(before), isTrue);
~~~

The host exposes the real runtime for assertions against specific registries.
PluginContributionSnapshot captures total registry counts and computes
before/after differences; it does not claim that a contribution belongs to a
particular plugin. Use stable contribution IDs and the runtime's owner-scoped
cleanup behavior for ownership assertions.

## Failure scenarios

Use ordinary plugin fakes to inject failures at lifecycle boundaries:

- Register one or more contributions, then throw from activate to verify
  partial registration cleanup.
- Throw from deactivate to verify that host-owned contributions are still
  removed and the manager no longer considers the plugin active.
- Use close() to attempt orderly deactivation of every active plugin. If any
  deactivation fails, the first failure is rethrown after all active plugins
  have been attempted.

## Scope and limitations

- This package is a dev_dependency; it is not required by production hosts.
- It exercises in-process lifecycle behavior. It is not a sandbox and does not
  isolate plugin code.
- Snapshots are aggregate registry counts, not per-owner audit records.
- It does not simulate process crashes, durable storage, cross-process races,
  or external side-effect recovery. Test those in the relevant adapter/host
  integration suite.

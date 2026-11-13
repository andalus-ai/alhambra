# Capability Provider Registry

## Purpose

The capability provider registry is the host-side source of truth for runtime
capability declarations. It is deliberately separate from plugin loading,
capability negotiation, and capability authorization:

- Providers publish what they implement and whether it is currently available.
- The negotiator compares a plugin's requirements with a stable registry snapshot.
- The capability broker and policy layer remain responsible for authorization.

A declaration is metadata, not a permission grant.

## Ownership model

Each host component registers declarations under a stable, non-empty owner ID.
An owner may publish multiple declarations, including multiple versions of the
same capability. This supports hosts that expose compatibility implementations
or multiple provider versions.

- `register` creates an owner registration and rejects duplicate owners.
- `replace` atomically replaces the complete declaration set for an owner.
- `unregister` withdraws every declaration belonging to an owner.
- `snapshot` returns an immutable, deterministically ordered view.
- `changes` emits a complete snapshot after each successful mutation.

Use `replace` rather than unregister/register when refreshing a provider. It
avoids an intermediate empty state being observed by consumers.

## Revision and snapshot semantics

The registry increments its monotonically increasing revision once per
successful mutation. A snapshot captures both that revision and a defensive,
unmodifiable copy of the declarations. Later registrations, replacements, or
withdrawals do not mutate earlier snapshots.

Dart's synchronous mutation methods execute atomically with respect to other
Dart code on the same isolate: no asynchronous work is awaited during a
mutation. Consumers should capture one snapshot at the beginning of a
negotiation/activation decision and use that same declaration list throughout
that decision. Do not repeatedly query the live registry while evaluating
individual requirements.

The change stream is broadcast and does not replay historical events. A
consumer that needs the current state should call `snapshot()` after
subscribing; revisions allow it to detect whether a newer state has arrived.

## Lifecycle

Call `close()` when the host runtime is shutting down. Closing prevents
further mutations and closes the change stream. Existing snapshots remain
readable and valid. Closing is idempotent.

## Example

```dart
final providers = CapabilityProviderRegistry();

providers.register(
  ownerId: 'builtin.storage',
  declarations: const [
    PluginCapabilityDeclaration(
      id: CapabilityId('sample.storage'),
      major: 1,
      minor: 2,
    ),
  ],
);

final stableView = providers.snapshot();
final result = const PluginCapabilityNegotiator().negotiate(
  requirements: const [
    PluginCapabilityRequirement(
      id: CapabilityId('sample.storage'),
      major: 1,
      minimumMinor: 2,
    ),
  ],
  declarations: stableView.declarations,
);
```

## Boundaries and future integration

The registry does not load provider code, probe remote services, choose a
provider implementation, or grant capabilities. Availability is explicitly
published by the owner; hosts should update it when their own health/lifecycle
signals change.

The existing `PluginManager` static declaration configuration remains
backward compatible. A subsequent integration step can inject this registry
into manager activation so every activation captures exactly one current
snapshot, while preserving the existing explicit declaration path for simple
hosts and tests.

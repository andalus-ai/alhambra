# Dynamic Capability Provider Integration

## Activation contract

PluginManager can use either a fixed declaration list or a
CapabilityProviderRegistry. Both modes use the same PluginCapabilityNegotiator
and requirements resolver.

Configure dynamic discovery with:

- capabilityNegotiator
- capabilityProviderRegistry
- capabilityRequirementsResolver

Do not also pass non-empty static capabilityDeclarations. The constructor
rejects mixed configuration to avoid ambiguous precedence. Existing static
configuration and PluginManager() remain supported.

## Snapshot consistency

For every activation attempt, PluginManager captures one immutable registry
snapshot and negotiates against that snapshot's declarations. The decision
therefore cannot mix provider revisions if the registry changes while plugin
activation is awaiting asynchronous work.

The resulting PluginCapabilityNegotiationRecord exposes:

- result: the compatibility/degradation outcome
- providerRevision: the exact registry revision used, or null for static mode

The same revision is attached to PluginCapabilityNegotiationException when a
required capability is incompatible. The legacy capabilityNegotiations getter
continues to expose the result map for existing callers.

A provider update affects subsequent activation attempts. It does not silently
re-negotiate or deactivate plugins that are already active. Hosts that need
runtime revocation must implement an explicit policy, notification, and
deactivation workflow; registry publication alone is not a security revocation
mechanism.

## Security and lifecycle

Registry declarations express provider availability and version compatibility.
They do not grant access. Runtime authorization remains the responsibility of
the capability broker and policy layer.

The host owns the registry lifecycle and should close it during runtime
shutdown, after dependent managers and consumers have stopped using it.

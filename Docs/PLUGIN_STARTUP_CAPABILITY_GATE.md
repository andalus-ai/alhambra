# Plugin Startup Capability Gate

PluginManager can enforce the capability compatibility contract introduced by PluginCapabilityNegotiator at the single plugin activation boundary.

## Host configuration

The host supplies:

- a PluginCapabilityNegotiator;
- the declarations available in the current runtime/deployment;
- a PluginCapabilityRequirementsResolver that returns requirements for a plugin instance.

The resolver is host-owned intentionally. A plugin's identity and declared permissions do not determine which provider versions are installed in a particular deployment.

## Activation behavior

1. PluginManager.activate serializes lifecycle work for the plugin.
2. Negotiation runs before AlhambraPlugin.activate.
3. An incompatible result throws PluginCapabilityNegotiationException; plugin code is never invoked.
4. Compatible results proceed to plugin activation and contribution validation.
5. Degraded results (optional requirements unavailable) proceed, and the result remains available through manager.capabilityNegotiations.

PluginStartupCoordinator already delegates every activation to PluginManager, so dependency-ordered batch startup receives the same gate. A required mismatch therefore fails the batch at that plugin and triggers the coordinator's existing reverse-order rollback for plugins activated earlier in the batch.

## Security boundary

Negotiation is compatibility discovery, not authorization. It does not grant capabilities, create scopes, or bypass the capability broker. Existing capability policy and broker checks remain authoritative for runtime access.

## Backward compatibility

Negotiation is opt-in. Existing PluginManager() construction preserves its previous behavior. When enabled, the negotiator and requirements resolver must be provided together; the manager rejects incomplete configuration early.

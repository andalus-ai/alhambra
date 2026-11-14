# Capability Provider Health and Revocation Planning

## Separation of responsibilities

Capability discovery, provider health, compatibility, and authorization are
separate concerns:

- CapabilityProviderRegistry publishes provider declarations and availability
  metadata used for compatibility negotiation.
- CapabilityProviderHealthMonitor records operational health transitions.
- CapabilityRevocationPlanner maps health changes to host-selected impact
  recommendations for active plugins.
- The capability broker and policy layer remain the authorization boundary.

A healthy provider is not automatically authorized, and an unavailable provider
does not itself revoke a permission.

## Health publication

The monitor is host-driven. It does not perform network probes, process checks,
or scheduled polling. Provider adapters publish health based on their own
signals using the owner ID shared with capability registration.

States are healthy, degraded, and unavailable. Each meaningful transition
increments a global revision and emits an immutable snapshot. Re-publishing an
identical state and reason is a no-op. A health record includes its own revision,
observation timestamp, reason, and previous state so recovery transitions can
be distinguished from initial healthy registration.

Call forget when an owner is removed from the host's health domain. Close the
monitor during host shutdown.

## Impact planning

The host supplies:
- the current immutable health snapshot;
- the active plugin IDs;
- a dependency map from plugin ID to provider owner IDs;
- one failure policy.

The planner returns immutable decisions only for active plugins with tracked
unhealthy dependencies, or for a provider that has just recovered. Results are
deterministically ordered by plugin ID and provider owner ID.

Policies map to recommendations:

| Policy | Planner action |
| --- | --- |
| notify | notify |
| degrade | markDegraded |
| suspend | suspend |
| deactivate | deactivate |

Recovery produces a recovered action, leaving the host to decide whether to
resume a suspended plugin or simply notify it.

## Deliberate non-automation

This phase intentionally does not call PluginManager.deactivate, mutate plugin
state, or alter capability grants. A planner must not unexpectedly interrupt
user work. The host can consume monitor changes, evaluate impact, apply its
governance policy, and execute lifecycle operations through the existing
PluginManager and lifecycle coordinators.

A later lifecycle adapter can execute approved decisions with idempotency,
ordering, rollback, and audit records. In particular, suspension needs a
formal plugin lifecycle contract before it can be safely automated.

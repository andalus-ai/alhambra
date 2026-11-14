# Governed Plugin Revocation Execution

## Responsibility boundary

Capability health monitoring and impact planning produce recommendations. They
do not authorize or execute plugin lifecycle operations. The
PluginRevocationCoordinator is the explicit host-controlled execution boundary.

The host supplies:
- impact decisions from the health planner;
- an approval callback;
- an idempotency execution store;
- an audit sink;
- optionally, PluginRuntimeHealthRegistry for degraded/recovered projections.

## Approval

Every decision passes through the host approval callback before execution.
Approval is evaluated per decision so hosts can apply tenant, environment,
severity, or operator-approval policy. Rejected decisions are recorded and are
not applied.

## Execution semantics

- deactivate uses PluginManager.deactivate, preserving its per-plugin
  serialization and resource cleanup behavior.
- markDegraded updates PluginRuntimeHealthRegistry only; it does not stop the
  plugin or grant/revoke capability permissions.
- recovered moves a degraded health projection back to active. It does not
  restart a stopped plugin.
- notify is recorded as a host-delegated no-op; the host event consumer owns
  notification delivery.
- suspend is explicitly unsupported until the public plugin API defines
  suspend/resume semantics.

Decisions are processed deterministically inside PluginManager's exclusive
lifecycle batch gate.

## Idempotency and crash recovery

Each decision is keyed by operation ID, plugin ID, provider owner ID, and
action. The coordinator writes a pending marker before invoking the lifecycle
operation. Completed and rejected decisions are not executed again.

A pending or failed record is treated as requiring reconciliation, not as
permission to retry. This is intentional: a process can stop after the plugin
was deactivated but before the result was durably recorded. The host must
compare the persisted record with authoritative PluginManager/runtime state
before deciding whether to retry or mark completion.

Production stores shared across processes must implement atomic
create-if-absent for writePending and durable completion. The in-memory
implementation is only for tests and single-process examples.

## Audit

Every completed, rejected, no-op, unsupported, or failed outcome is sent to
the injected audit sink after its execution record is persisted. The record
contains operation and idempotency IDs, plugin/provider IDs, action, outcome,
timestamp, and a sanitized detail string. Do not put credentials, provider
payloads, or arbitrary exception messages in audit details.

## Deliberate limitations

This implementation does not automatically suspend plugins, resume stopped
plugins, revoke broker grants, or retry ambiguous operations. Those require
separate contracts for suspension, authorization, and durable reconciliation.

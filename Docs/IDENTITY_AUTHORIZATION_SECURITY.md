# Identity Authorization Security Contract

> **Status:** Hardened reference authorization behavior. Production readiness still depends on host trust boundaries, durable adapters, configuration, and deployment-specific testing.

## 1. Authorization behavior

`DefaultAuthorizationService` now follows deny-by-default behavior for the checks it owns:

- A tenant-bound resource requires an explicit request organization equal to the resource organization. A missing request organization is a mismatch.
- A `UserPrincipal` requires an explicit organization, a configured membership repository, an active membership, a configured role repository, and at least one resolved role containing the requested permission.
- Missing repositories, missing membership, inactive membership, missing roles, or missing permissions deny.
- `AgentPrincipal` and `ServicePrincipal` require explicit permission allowlists supplied by the host.
- `SystemPrincipal` is denied unless its permission key appears in the host-configured system permission allowlist. It does not bypass tenant/resource scope checks.
- Explicit deny policies veto an otherwise authorized request. Optional policies are deny-only vetoes; an allow policy does not independently grant access.
- Unknown or absent permission grants deny.

## 2. Principal trust boundary

A principal object is an in-process identity representation, not proof of authentication.

In particular, `SystemPrincipal` is a public value type and can be constructed by code running in the process. Its permission allowlist is a defense against accidental blanket grants, not a cryptographic identity boundary. Hosts MUST:
- construct principals only after authenticating or establishing the actor through a trusted boundary;
- never deserialize an untrusted client-supplied principal type or trust a client-selected principal class;
- keep system-principal creation inside trusted host infrastructure;
- give system principals the smallest explicit permission set and avoid broad wildcard permissions;
- bind tenant/resource scope from trusted server-side data, not from a client assertion.

For stronger isolation, hosts should use separate service identities/credentials and narrowly scoped adapters rather than treating an in-process system marker as a security boundary.

## 3. Audit semantics

`AuthorizationAuditSink` is an asynchronous host adapter contract. A production adapter should commit the audit record durably before returning.

- Set `requireAudit: true` when a request must not be allowed unless its decision is persisted.
- With required audit enabled, a missing sink or sink failure returns a deny decision.
- With required audit disabled, a sink is best-effort and its persistence failure does not change the authorization decision.
- The legacy synchronous `auditCallback` is a notification hook only; it does not prove durability and is deprecated in favor of the sink contract.
- The separate `alhambra_identity_sqlite` package provides a SQLite audit-sink adapter. Other database adapters remain host/provider responsibilities.

Hosts remain responsible for audit schema, append-only controls, retention, access control, transaction boundaries, delivery/alerting, and operational recovery.

## 4. Persistence and deployment limitations

The in-memory membership and role repositories are test/reference implementations. The separate `alhambra_identity_sqlite` package supplies SQLite membership and role adapters for a trusted single-host deployment. SQLite is not automatically a shared multi-instance authorization store; clustered deployments need a database adapter designed for concurrent workers, transaction semantics, and immediate revocation visibility. A production host must validate consistency, backup/restore, encryption, revocation visibility, transaction behavior, and operational guarantees.

The permission maps for agent, service, and system principals are host-supplied configuration. They are not a distributed grant store or a replacement for an authenticated service identity system.

## 5. Required adversarial tests

Before production adoption, host/package tests must cover:
- absent organization context and tenant-resource scope mismatch;
- missing membership/role repositories;
- absent/inactive membership and unresolved/empty roles;
- missing permission and explicit deny policy;
- system principal with no grant, narrow grant, and cross-organization mismatch;
- unknown agent/service and unconfigured permission;
- required audit sink missing, successful, and failing;
- host authentication failure, spoofed principal input, stale grant/revocation, and concurrent permission changes.

The package tests cover a subset of these contracts. They do not prove the security of a host's authentication, storage adapters, or deployment.

## 6. Integration

See [Jezaku host integration contract](JEZAKU_HOST_INTEGRATION_CONTRACT.md) for the consumer boundary and adoption gates.

# Jezaku Host Integration Contract

> **Status:** Proposed consumer contract. This document defines intended boundaries; it does not claim a Jezaku integration or production guarantee is already implemented.

## 1. Purpose

Jezaku is a consumer of Alhambra's reusable application foundation. Integration must preserve Alhambra's product-neutral scope and Jezaku's ownership of domain behavior and backend security.

## 2. Responsibility boundary

| Concern | Alhambra owns | Jezaku owns |
|---|---|---|
| Flutter UI foundation | Shared shell, design primitives, reusable navigation/layout and UI composition | Jezaku information architecture, branding, feature screens and domain workflows |
| Plugin contracts/runtime | Generic contribution contracts, lifecycle, capability negotiation and host composition | Which Jezaku capabilities exist, their domain semantics and whether a contribution is enabled |
| Identity concepts | Generic identity/authorization contracts and adapters | Authoritative operator identity, durable grants, policy enforcement and audit in Quarkus |
| Safety | Generic platform extension points only | Spatial safety, moderation, authority verification and policy precedence |
| Commerce | Generic UI/plugin mechanisms | Merchants, campaigns, advertising eligibility, payment/redemption and marketplace governance |
| Spatial | Generic extension points only | AR objects, anchors, geospatial placement, navigation and spatial ownership |
| Operations | Reusable runtime lifecycle/health contracts | Deployment topology, operational policy, observability and privileged operations |

Alhambra must not acquire Jezaku-specific policy or become the source of truth for Jezaku domain records.

## 3. Consumer dependency policy

- Pin Alhambra package dependencies to an immutable Git commit or released package version.
- Do not use a moving branch as a production dependency.
- Record the selected revision, package versions, Dart/Flutter SDK constraints and upgrade notes.
- Verify transitive dependencies, including packages that use local path dependencies within the Alhambra repository, from a clean Jezaku checkout.
- Upgrade deliberately: review upstream changes, run Alhambra package tests, then run Jezaku analyze/tests/builds.
- Do not add the full plugin runtime to the admin app when only UI components are needed.

## 4. Backend authority and trust

- The Jezaku Quarkus backend is authoritative for operator authentication, grants, permission evaluation, resource scopes, approvals, and audit.
- Every privileged API validates the authenticated principal and current server-side grant/scope. Client route visibility, UI state, Alhambra capabilities, plugin manifests, and JWT role-like display hints are not authorization.
- Domain services validate ownership and domain invariants even when a request originated from an authenticated admin.
- High-impact operations use explicit approval/step-up controls where required by Jezaku policy.
- Alhambra's current identity authorization implementation is not approved as Jezaku's production enforcement point until its fail-closed behavior and persistence/audit adapters have been independently reviewed and tested.

## 5. Plugin execution and marketplace boundary

The Alhambra Flutter plugin runtime composes host-supplied plugin implementations. It must not be described or relied upon as a secure sandbox for arbitrary third-party Dart/native code downloaded from a marketplace.

Before Jezaku enables third-party extensions, define and validate:
- package provenance, publisher identity, signing-key lifecycle and integrity;
- explicit capability/permission declarations and host-side policy checks;
- compatibility, resource budgets, dependency policy and revocation;
- an execution isolation model that prevents untrusted code from obtaining unrestricted host-process privileges;
- review, staged rollout, monitoring, incident response and rollback.

A declarative, schema-validated contribution format may be appropriate for simple UI/content extensions. Executable extensions require a separately approved isolation design. Signature verification proves provenance/integrity under a trust policy; it does not provide runtime isolation.

## 6. Integration stages and gates

### Stage A — Architecture alignment
- Keep repositories separate.
- Publish ADR-0004 in Jezaku and this contract in Alhambra.
- Keep ownership tables and links current.

### Stage B — Alhambra security hardening
- Review authorization behavior for every principal type.
- Require explicit scope and configured policy dependencies; deny on missing security-critical configuration.
- Constrain privileged/system principals to explicit trusted host boundaries.
- Define audit sink semantics and distinguish callback notification from durable audit.
- Add adversarial tests for missing organization, repositories, roles, permissions, inactive membership, cross-scope access and privileged principals.
- Document which persistence adapters are reference/in-memory versus production-capable.

### Stage C — UI package adoption
- Validate package dependency resolution and SDK compatibility from Jezaku.
- Pin exact revisions.
- Integrate only the UI packages needed by `UI/jezaku_admin`.
- Preserve the backend authorization boundary and explicit disconnected/unavailable UI states.
- Run Flutter analyze, widget tests and supported builds.

### Stage D — Extension governance
- Design Jezaku marketplace policy and package lifecycle.
- Approve the execution isolation model before third-party executable extensions are accepted.
- Verify revocation behavior end-to-end, including already-running or offline clients.

## 7. Release checklist

- [ ] Dependency is pinned to immutable revision/version.
- [ ] Clean-checkout dependency resolution succeeds.
- [ ] SDK constraints and transitive dependencies are recorded.
- [ ] No client-side authorization is relied upon.
- [ ] Backend scope and permission checks are covered by negative tests.
- [ ] Durable audit behavior is verified for privileged operations.
- [ ] No untrusted downloaded code runs in the host process.
- [ ] Rollback to the previous Alhambra revision is documented.

## 8. Related documents

- Jezaku: [ADR-0004 — Alhambra as the Shared Platform Foundation](https://github.com/andalus-ai/jezaku/blob/main/docs/decisions/ADR-0004-alhambra-platform-foundation.md)
- Alhambra: [Application host composition](APPLICATION_HOST_COMPOSITION.md)
- Alhambra: [UI package boundaries](ALHAMBRA_UI_PACKAGE_BOUNDARIES.md)
- Alhambra: [Plugin package integrity and trust](PLUGIN_PACKAGE_INTEGRITY_AND_TRUST.md)
- Alhambra: [Plugin developer guide](PLUGIN_DEVELOPER_GUIDE.md)

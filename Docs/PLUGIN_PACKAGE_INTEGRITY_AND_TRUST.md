# Plugin Package Integrity and Publisher Trust

## Verification stages

The default package verifier separates three questions:

1. **Payload integrity** — does the digest computed from the canonical package payload match the declared SHA-256 digest?
2. **Publisher authenticity** — does a trusted, currently valid signing key verify the detached signature over Alhambra's versioned package statement?
3. **Host trust policy** — is the publisher blocked, and is the publisher explicitly trusted by this host?

A package is installable only when the verifier returns `PackageVerified`. The default verifier requires a payload integrity adapter for every package, including unsigned packages. Signed packages additionally require a cryptographic signature adapter and a matching trusted key. Missing adapters fail closed.

## Host adapter configuration

Alhambra defines interfaces, not cryptographic primitives. A host should select a maintained cryptographic library and implement:

- `PluginPayloadIntegrityVerifier` — computes SHA-256 over the canonical package payload.
- `PluginCryptographicSignatureVerifier` — verifies the package signature using the declared algorithm and trusted public key.

Inject both adapters through `ExtensionRuntime`:

```dart
final runtime = ExtensionRuntime(
  pluginPayloadIntegrityVerifier: platformPayloadDigest,
  pluginSignatureVerifier: platformSignatureVerifier,
);
```

The same runtime trust store is shared with its default package verifier. Register keys and publisher trust before package installation:

```dart
runtime.pluginTrustStore.addTrustedKey(
  TrustedKey(
    keyId: 'publisher-key-2026',
    algorithm: 'ed25519',
    publicKey: encodedPublicKey,
    publisherId: 'publisher.example',
    notBefore: keyValidFrom,
    notAfter: keyValidUntil,
  ),
);
runtime.pluginTrustStore.addTrustedPublisher('publisher.example');
```

The sample names above are illustrative; the key encoding and cryptographic implementation are owned by the host.

## Canonical signed statement

The API exposes `canonicalPluginPackageSigningStatement(package)`. Its UTF-8 statement is versioned with `alhambra-plugin-package-v1` and binds:

- plugin ID and manifest version;
- package metadata ID and version;
- package format version;
- normalized content digest; and
- publisher ID.

The digest adapter is responsible for hashing the canonical package payload bytes. Packagers and verifiers must agree on archive traversal, path normalization, metadata inclusion/exclusion, and file ordering. This repository does not yet define a concrete archive format or canonical archive encoder; hosts must not claim interoperability until that format is specified and tested.

## Key lifecycle and trust levels

Trusted keys can carry publisher binding, validity bounds and a revocation timestamp. The default verifier rejects unknown, revoked, not-yet-valid, expired, algorithm-mismatched and publisher-mismatched keys.

- `unsigned`: payload integrity matched, but no publisher signature was supplied and host policy allowed it.
- `verified`: payload integrity and signature were verified with a valid trusted key, but publisher is not explicitly trusted.
- `trusted`: payload integrity and signature were verified and the publisher is explicitly trusted.

Publisher trust is a host policy decision; it is not inferred from a valid signature. A key bound to a publisher must match the package publisher exactly.

## Installation gate

`DefaultPluginLifecycleManager.install` calls the configured `PluginPackageVerifier` before dependency resolution or writing installed state. A failed verification throws and does not stage the plugin as installed. Hosts should still use an isolated staging directory, atomic promotion, durable audit logging and rollback around their production package extraction/store adapters.

## Explicit limitations

- No cryptographic implementation is bundled. The injected adapter must use a vetted library and enforce algorithm/key-format constraints.
- The in-memory trust store is a reference implementation, not a durable key-management service.
- Key revocation is checked against the trust store's current snapshot; no transparency log, online revocation protocol, timestamp authority or historical signing-time validation is implemented.
- Publisher trust and key metadata need an authenticated administrative update channel.
- The canonical statement is versioned, but canonical archive bytes and a concrete package archive format remain host responsibilities.
- The current in-memory installation manager is not an atomic filesystem installer and does not provide crash-safe promotion or rollback.
- Unsigned packages may be permitted by policy, but are never labeled verified or trusted.

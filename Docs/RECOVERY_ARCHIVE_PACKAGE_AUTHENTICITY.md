# Recovery Archive Package Authenticity

## Purpose

Portable package digests detect modification relative to the digest supplied
with the package. They do not prove who created it. This extension adds
detached signatures and host-owned trust assessment without embedding
cryptography providers, private keys, or a trust store in Alhambra.

## Signing

1. Create a verified portable package using
   `PluginRecoveryArchivePackageExporter`.
2. Call `PluginRecoveryArchivePackageSigningService.sign()` with an explicit
   signature algorithm and key identifier.
3. The host signer signs a domain-separated payload binding the signature
   algorithm and key identifier to the deterministic full package encoding,
   including manifest, records, and package digest.
4. Serialize the signed envelope with
   `PluginRecoveryArchiveSignedPackageCodec`.

The signer contract should be backed by a protected KMS/HSM or equivalent
signing service. Do not pass private key bytes into Alhambra or store them in
package metadata.

## Verification and trust

`PluginRecoveryArchivePackageAuthenticityVerifier` performs two distinct
checks:

- The host trust policy assesses producer/key binding, key status, validity
  windows, and permitted algorithms.
- The host signature verifier validates the signature over the exact package
  encoding.

Unknown, revoked, disallowed, unsupported, and invalid signatures fail closed.
A valid cryptographic signature is not sufficient unless the host trust policy
also considers its signer trusted.

## Authenticated import

Hosts that require signed packages should expose
`PluginRecoveryArchiveAuthenticatedPackageImporter` as their import path.
It verifies authenticity before preview, then rechecks trust and signature
immediately before delegating to the archive-only importer. The underlying
importer still validates package and per-record digests, schema and format,
terminal status, destination conflicts, and read-back consistency.

Do not expose the lower-level unauthenticated importer to untrusted import
entrypoints when signatures are mandatory. Alhambra cannot prevent a host from
bypassing its own policy by directly calling lower-level APIs.

## Host responsibilities and limitations

- Provision and protect signing keys; define signer identities and producer
  bindings.
- Maintain trust roots, revocation state, key validity windows, rotation,
  algorithm allow-lists, and audit records.
- Define whether old signatures remain valid after key rotation or revocation.
- Enforce authorization independently of signature validity.
- Keep package size, record count, replay, and retention controls at the host
  boundary.
- Treat signature verification as a point-in-time decision. Hosts with strict
  revocation consistency requirements should provide a trust policy backed by
  strongly consistent state and coordinate policy changes with imports.
- A signature authenticates the signed bytes; it does not establish that the
  archived job history is truthful, complete, or safe to execute.
- Import remains archive-only. No plugin hooks, checkpoints, operational jobs,
  or recovery execution are touched.

The test signer and digest fixtures are deterministic test doubles, not
production cryptography.

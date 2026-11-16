# Portable Recovery Archive Packages

## Purpose

Portable packages move terminal recovery-job archive records between host
deployments without coupling Alhambra to a filesystem, database, object store,
or transport. The package format is versioned independently from the archive
snapshot format.

## Export

Use `PluginRecoveryArchivePackageExporter.create()` with an explicit package
ID, producer identifier, creation timestamp, records, digest provider, and
algorithm. Export accepts only current-schema, current-format terminal records.
The package contains a manifest, sorted records, each record's existing archive
integrity envelope, and a package-level digest.

The host supplies the digest implementation. Use a vetted cryptographic
algorithm such as SHA-256 in production. The package digest covers the
canonical manifest and complete record content; each record digest is checked
independently on import.

## Transport

`PluginRecoveryArchivePackageCodec.encode()` produces a UTF-8 JSON document;
`decode()` validates the shape, enum values, timestamps, manifest count, and
unique job IDs before creating typed records. Hosts may store or transfer these
bytes using any mechanism. The format contains sanitized recovery metadata
only; it must not be extended with credentials, plugin instances, secrets, or
arbitrary executor state.

## Preview and import

1. Decode the package.
2. Call `PluginRecoveryArchivePackageImporter.inspect()` to verify the
   package digest, every record digest, supported versions, terminal status,
   and destination conflicts.
3. Present the immutable plan to an authorized operator.
4. Call `importPackage(plan)` only after approval.

Import writes only to the archive adapter. It never inserts into the
operational recovery-job store, mutates checkpoints, invokes plugin hooks, or
resumes a recovery job. Identical existing records are treated as already
present; conflicting records block preview.

The importer re-inspects before writing. Each destination write relies on the
archive adapter's atomic `putIfAbsent` contract and is read back for equality.
If a race or adapter failure occurs after earlier records were written, the
report identifies imported, already-present, and conflicting IDs. Import is
therefore per-record atomic, not a multi-record transaction; no automatic
rollback is attempted because the archive contract does not require deletion.

## Security and compatibility boundaries

- Package digests provide integrity, not authenticity or authorization.
- Digital signatures, trust roots, key rotation, and signer identity remain
  host responsibilities and are not implied by a valid digest.
- The package format version and archive snapshot format version are distinct.
- Unknown package formats, job schemas, archive formats, and enum values fail
  closed.
- The importer does not automatically migrate old archive formats. Migrate
  records explicitly with the archive migration API, then export the verified
  current-format copies.
- Hosts must enforce package size, record count, provenance, authorization,
  and retention policies before import.
- A digest algorithm identifier is metadata, not proof that an implementation
  is cryptographically strong.

## Validation

The package tests cover JSON round-trip, malformed enum rejection, duplicate
IDs, package and per-record digest failures, successful import, destination
conflicts, idempotent already-present records, and safe handling of a same-
record destination race. Tests being present does not imply they have run.

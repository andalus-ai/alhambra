# Alhambra Local Plugin Installation Filesystem

Optional local-disk implementation of `FencedPluginInstallFileSystem`.

## Usage

```dart
final fileSystem = LocalPluginInstallFileSystem(
  rootDirectory: Directory('/var/lib/alhambra'),
);

await fileSystem.initialize();

final ready = await fileSystem.advanceFence(
  operationId: operationId,
  fencingToken: lease.fencingToken,
);
if (!ready) throw StateError('A newer worker already owns this operation.');
```

The adapter stores plugin payloads below `plugins/` and operation state,
staging data and per-operation locks below `.alhambra-install-state/`.
Staging and destination must reside on the same local filesystem because
promotion uses a directory rename.

## Safety properties

- All mutation methods acquire an exclusive per-operation lock and re-check
  the exact fencing token while holding that lock.
- The highest accepted token is persisted in operation metadata.
- Lower tokens cannot write, promote, roll back, finalize or discard staging.
- Archive paths are relative, normalized, traversal-safe and cannot overwrite
  the reserved ownership marker.
- Existing destinations are never overwritten.
- Promotion intent is persisted before the directory rename, allowing
  read-only inspection to identify an interrupted promotion.
- A host ownership marker is retained in the installed directory so recovery
  can prove provenance after a crash between promotion and journal commit.
- Inspection is read-only and verifies the operation/plugin identity.

## Operational constraints

- This is a local filesystem adapter, not a distributed filesystem lock.
- A process crash may leave an operation lock directory behind. The adapter
  intentionally does not steal stale locks based on age; a host operator must
  reconcile the operation and remove a proven abandoned lock before retry.
- Use a local filesystem with reliable same-volume rename semantics. Network
  filesystems and object stores are not supported by this implementation.
- The hidden `.alhambra-install-owner.json` file is reserved host metadata and
  remains in the installed plugin directory as durable ownership evidence.
  Plugin packages cannot create this filename.
- This adapter does not coordinate an atomic transaction with SQLite or the
  installed-record store. Recovery remains a host-approved saga.
- Fencing token zero is accepted only for non-lease, single-worker mode. When
  lease mode is enabled, use the positive token issued by the durable lease
  store and wire fenced journal and installed-record adapters as well.

## Validation

Tests cover staging/extraction, promotion/rollback, stale-token rejection,
destination collision and path traversal. Run `dart pub get`, `dart format`,
`dart analyze` and `dart test` in a configured Dart environment before
production use.

# Alhambra Plugin Runtime

Host-side runtime for registering, composing, reconciling, and observing plugin
contributions. This package depends on the framework-neutral
`alhambra_plugin_api` contracts and does not depend on a product UI.

## Composition lifecycle observability

`DefaultCompositionRuntime` implements
`CompositionLifecycleObservability`. It retains a bounded event history,
provides correlation and owner projections, and offers bounded asynchronous
event subscriptions.

```dart
final runtime = DefaultCompositionRuntime(
  maxLifecycleEvents: 2000,
  maxLifecycleEventSubscribers: 32,
  maxPendingLifecycleEventsPerSubscriber: 256,
);

final subscription = runtime.subscribeLifecycleEvents((event) {
  // Keep observers fast. Delivery is asynchronous and isolated from lifecycle
  // callbacks, but callback work should still be handed off to a worker.
  print('${event.correlationId}: ${event.operation.name} ${event.status.name}');
});

final transaction = runtime.beginTransaction(
  correlationId: 'install-editor',
  lifecycle: editorLifecycle,
)..stage(CommandNode(commandId: 'save', ownerId: 'editor'));

transaction.commit();

final timeline = runtime.timelineForCorrelation('install-editor');
final owner = runtime.ownerLifecycleSummary('editor');
final recentFailures = runtime.queryLifecycleEvents(
  status: CompositionLifecycleStatus.failed,
  limit: 50,
);

subscription.cancel();
```

### Delivery and backpressure

- Lifecycle events are added to in-memory history synchronously.
- Subscriber callbacks run in microtasks, never inline in a composition callback.
- Each subscriber has its own bounded pending queue. The default capacity is
  128 events; the newest event is dropped for that subscriber when full.
- The default subscriber limit is 64. Exceeding it throws `StateError` rather
  than silently creating unbounded fan-out.
- `droppedLifecycleEventCount` reports aggregate subscriber drops;
  `subscription.droppedEventCount` reports drops for one subscriber.
- Listener exceptions are isolated. They do not change composition results.
- Cancellation removes the subscriber and clears its queued events.
- The event history defaults to 1,000 events and is a rolling in-memory window.
  Query and timeline results are therefore limited to retained history.

### Queries and projections

`queryLifecycleEvents` supports correlation ID, owner ID, operation, status,
inclusive `from`/`to` bounds, exclusive `before` pagination, and a result
limit. Results retain event order (oldest first). `timelineForCorrelation`
is a convenience projection. Owner summaries include current runtime state,
retained event/failure counts, last event time, and last retained failure.

The observability contracts live in `alhambra_plugin_api`; implementations
can be replaced without coupling consumers to JSONL, a database, or a telemetry
vendor. The JSONL lifecycle runtime facade also exposes the runtime's
subscription and in-memory query methods, while its `query()` method reads
durable history after flushing accepted journal events.

## Packages

- `alhambra_plugin_api`: stable plugin and observability contracts.
- `alhambra_plugin_runtime`: in-memory composition runtime and observability.
- `alhambra_lifecycle_file_store`: optional durable JSONL adapter.

## Plugin package integrity and trust

The default `DefaultPluginPackageVerifier` fails closed unless a host injects
a `PluginPayloadIntegrityVerifier`. Signed packages also require a
`PluginCryptographicSignatureVerifier`. These interfaces deliberately do not
bundle cryptographic primitives; select a vetted implementation in the host.

```dart
final runtime = ExtensionRuntime(
  pluginPayloadIntegrityVerifier: payloadDigestAdapter,
  pluginSignatureVerifier: signatureAdapter,
);

runtime.pluginTrustStore.addTrustedKey(
  TrustedKey(
    keyId: 'publisher-key',
    algorithm: 'ed25519',
    publicKey: encodedPublicKey,
    publisherId: 'publisher.example',
    notBefore: keyValidFrom,
    notAfter: keyValidUntil,
  ),
);
runtime.pluginTrustStore.addTrustedPublisher('publisher.example');
```

The runtime shares one trust-store instance with its default package verifier.
Unsigned packages can be permitted by policy, but still require payload
integrity verification and remain classified as `unsigned`. A signed package
is `verified` after digest and signature verification; it is `trusted` only
when its publisher is explicitly trusted. See
[Plugin Package Integrity and Trust](../../Docs/PLUGIN_PACKAGE_INTEGRITY_AND_TRUST.md)
for canonical statement and key lifecycle boundaries.

## Transactional package installation

`TransactionalPluginInstaller` verifies a package, runs host preflight,
extracts an archive into an isolated staging area under bounded resource
limits, promotes it reversibly, and persists the installed-plugin record.
It does not load or execute downloaded code or activate plugins.

Hosts must provide `PluginPackageArchive`, `PluginInstallPreflight`,
`PluginInstallFileSystem`, `TransactionalInstalledPluginStore` and a durable
`PluginInstallJournal` adapter. The installed-record adapter must implement
atomic create-if-absent and compare-and-remove semantics. Filesystem
implementations must independently enforce staging-root containment and safe
exclusive writes. The journal and filesystem adapters must support
reconciliation of interrupted operations; in-memory test doubles are not
production durability guarantees.

See [Transactional Plugin Installation](../../Docs/TRANSACTIONAL_PLUGIN_INSTALLATION.md)
for the transaction sequence, archive threat model and recovery limitations.

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _Plugin implements AlhambraPlugin {
  _Plugin(this.id);
  final String id;
  @override
  PluginMetadata get metadata => PluginMetadata(id: id, name: id, version: '1.0.0');
  @override
  Future<void> activate(PluginContext context) async {}
  @override
  Future<void> deactivate(PluginContext context) async {}
}

PluginRevocationJournalRecord _record({
  String pluginId = 'consumer',
  CapabilityImpactAction action = CapabilityImpactAction.deactivate,
  PluginRevocationJournalStatus status = PluginRevocationJournalStatus.pending,
  int revision = 0,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return PluginRevocationJournalRecord(
    revision: revision,
    idempotencyKey: 'key-$pluginId',
    operationId: 'operation-1',
    correlationId: 'trace-1',
    pluginId: pluginId,
    providerOwnerId: 'provider',
    action: action,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PluginRevocationJournalStore', () {
    test('creates once and enforces revision compare-and-set', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final initial = _record();
      expect(await store.createIfAbsent(initial), isTrue);
      expect(await store.createIfAbsent(initial), isFalse);

      final replacement = initial.nextRevision(
        status: PluginRevocationJournalStatus.reconciled,
        updatedAt: DateTime.utc(2026, 1, 2),
        detail: 'verified',
      );
      expect(await store.compareAndSet(
        idempotencyKey: initial.idempotencyKey,
        expectedRevision: 0,
        replacement: replacement,
      ), isTrue);
      expect(await store.compareAndSet(
        idempotencyKey: initial.idempotencyKey,
        expectedRevision: 0,
        replacement: replacement,
      ), isFalse);
      expect((await store.read(initial.idempotencyKey))!.revision, 1);
    });
  });

  group('PluginRevocationRecoveryPlanner', () {
    test('classifies interrupted deactivation without retrying it', () async {
      final store = InMemoryPluginRevocationJournalStore();
      await store.createIfAbsent(_record());
      final manager = PluginManager();

      final report = await PluginRevocationRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect();

      expect(report.findings.single.disposition,
          PluginRevocationRecoveryDisposition.runtimeInactiveNeedsExternalVerification);
      expect(report.isConsistent, isFalse);
      expect((await store.readAll()).single.status,
          PluginRevocationJournalStatus.pending);
    });

    test('flags completed deactivation while plugin is active', () async {
      final store = InMemoryPluginRevocationJournalStore();
      final pending = _record();
      await store.createIfAbsent(pending);
      final completed = pending.nextRevision(
        status: PluginRevocationJournalStatus.completed,
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await store.compareAndSet(
        idempotencyKey: pending.idempotencyKey,
        expectedRevision: 0,
        replacement: completed,
      );
      final manager = PluginManager();
      await manager.activate(_Plugin('consumer'));

      final report = await PluginRevocationRecoveryPlanner(
        store: store,
        manager: manager,
      ).inspect();

      expect(report.findings.single.disposition,
          PluginRevocationRecoveryDisposition.runtimeStillActiveAfterCompletion);
    });

    test('requires subsystem inspection for projection-only actions', () async {
      final store = InMemoryPluginRevocationJournalStore();
      await store.createIfAbsent(_record(
        action: CapabilityImpactAction.markDegraded,
      ));
      final report = await PluginRevocationRecoveryPlanner(
        store: store,
        manager: PluginManager(),
      ).inspect();

      expect(report.findings.single.disposition,
          PluginRevocationRecoveryDisposition.manualReview);
    });
  });

  test('journal-backed store persists coordinator outcomes and correlation IDs', () async {
    final journal = InMemoryPluginRevocationJournalStore();
    final executionStore = JournalBackedPluginRevocationExecutionStore(
      journal: journal,
      correlationIdFor: (_) => 'trace-provider-event-9',
    );
    final coordinator = PluginRevocationCoordinator(
      manager: PluginManager(),
      executionStore: executionStore,
      auditSink: InMemoryPluginRevocationAuditSink(),
      approve: (_) => true,
    );
    final report = await coordinator.execute(
      operationId: 'provider-event-9',
      decisions: [
        CapabilityImpactDecision(
          pluginId: 'consumer',
          providerOwnerId: 'provider',
          providerState: CapabilityProviderHealthState.unavailable,
          action: CapabilityImpactAction.notify,
          reason: 'provider unavailable',
        ),
      ],
    );

    final persisted = (await journal.readAll()).single;
    expect(report.records.single.status, PluginRevocationExecutionStatus.noOp);
    expect(persisted.status, PluginRevocationJournalStatus.noOp);
    expect(persisted.correlationId, 'trace-provider-event-9');
    expect(persisted.revision, 1);
  });

  test('resolver uses CAS and never retries plugin code', () async {
    final store = InMemoryPluginRevocationJournalStore();
    await store.createIfAbsent(_record());
    final resolved = await PluginRevocationJournalResolver(
      store: store,
      clock: () => DateTime.utc(2026, 1, 2),
    ).resolve(
      idempotencyKey: 'key-consumer',
      expectedRevision: 0,
      resolution: 'external resources verified clean',
    );

    expect(resolved.status, PluginRevocationJournalStatus.reconciled);
    expect(resolved.revision, 1);
    expect(resolved.detail, contains('external resources verified clean'));
  });
}

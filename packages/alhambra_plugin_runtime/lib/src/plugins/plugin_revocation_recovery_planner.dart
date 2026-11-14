import '../capabilities/capability_provider_health.dart';
import 'plugin_manager.dart';
import 'plugin_revocation_journal.dart';

/// Read-only recovery classification for one durable revocation entry.
enum PluginRevocationRecoveryDisposition {
  terminal,
  actionOutcomeUnknown,
  runtimeInactiveNeedsExternalVerification,
  runtimeStillActiveAfterCompletion,
  manualReview,
}

final class PluginRevocationRecoveryFinding {
  final PluginRevocationJournalRecord record;
  final bool pluginIsActive;
  final PluginRevocationRecoveryDisposition disposition;
  final String guidance;

  const PluginRevocationRecoveryFinding({
    required this.record,
    required this.pluginIsActive,
    required this.disposition,
    required this.guidance,
  });

  bool get requiresHostAction =>
      disposition != PluginRevocationRecoveryDisposition.terminal;
}

final class PluginRevocationRecoveryReport {
  final DateTime inspectedAt;
  final List<PluginRevocationRecoveryFinding> findings;

  PluginRevocationRecoveryReport({
    required this.inspectedAt,
    required Iterable<PluginRevocationRecoveryFinding> findings,
  }) : findings = List.unmodifiable(findings);

  List<PluginRevocationRecoveryFinding> get requiringHostAction =>
      List.unmodifiable(findings.where((finding) => finding.requiresHostAction));

  bool get isConsistent => requiringHostAction.isEmpty;
}

/// Compares durable revocation intents with authoritative PluginManager state.
///
/// This planner never executes, retries, approves, or mutates an operation.
/// An inactive plugin is not proof that plugin-owned external resources were
/// cleaned up; hosts must verify those independently before resolving a record.
class PluginRevocationRecoveryPlanner {
  final PluginRevocationJournalStore store;
  final PluginManager manager;
  final DateTime Function() _clock;

  PluginRevocationRecoveryPlanner({
    required this.store,
    required this.manager,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginRevocationRecoveryReport> inspect() =>
      manager.runExclusiveLifecycleBatch(_inspect);

  Future<PluginRevocationRecoveryReport> _inspect() async {
    final activeIds = <String>{};
    for (final plugin in manager.activePlugins) {
      final id = plugin.metadata.id.trim();
      if (id.isEmpty || !activeIds.add(id)) {
        throw StateError('PluginManager contains an empty or duplicate active plugin ID.');
      }
    }

    final entries = await store.readAll();
    final keys = <String>{};
    final findings = <PluginRevocationRecoveryFinding>[];
    for (final record in entries) {
      if (!keys.add(record.idempotencyKey)) {
        throw StateError('Journal returned duplicate idempotency keys.');
      }
      final active = activeIds.contains(record.pluginId);
      findings.add(_classify(record, active));
    }
    findings.sort((a, b) {
      final byPlugin = a.record.pluginId.compareTo(b.record.pluginId);
      if (byPlugin != 0) return byPlugin;
      return a.record.idempotencyKey.compareTo(b.record.idempotencyKey);
    });
    return PluginRevocationRecoveryReport(
      inspectedAt: _clock().toUtc(),
      findings: findings,
    );
  }

  PluginRevocationRecoveryFinding _classify(
    PluginRevocationJournalRecord record,
    bool active,
  ) {
    if (record.status == PluginRevocationJournalStatus.pending ||
        record.status == PluginRevocationJournalStatus.failed) {
      if (record.action == CapabilityImpactAction.deactivate && !active) {
        return PluginRevocationRecoveryFinding(
          record: record,
          pluginIsActive: false,
          disposition: PluginRevocationRecoveryDisposition.runtimeInactiveNeedsExternalVerification,
          guidance: 'PluginManager reports inactive. Verify plugin-owned external '
              'resources and cleanup effects before marking this operation reconciled.',
        );
      }
      if (record.action == CapabilityImpactAction.deactivate && active) {
        return PluginRevocationRecoveryFinding(
          record: record,
          pluginIsActive: true,
          disposition: PluginRevocationRecoveryDisposition.actionOutcomeUnknown,
          guidance: 'Deactivation outcome is ambiguous. Inspect plugin state and '
              'partial teardown; do not automatically invoke deactivate again.',
        );
      }
      return PluginRevocationRecoveryFinding(
        record: record,
        pluginIsActive: active,
        disposition: PluginRevocationRecoveryDisposition.manualReview,
        guidance: 'This action is not fully observable through PluginManager. '
            'Inspect its authoritative subsystem and side effects before resolution.',
      );
    }

    if (record.status == PluginRevocationJournalStatus.completed &&
        record.action == CapabilityImpactAction.deactivate &&
        active) {
      return PluginRevocationRecoveryFinding(
        record: record,
        pluginIsActive: true,
        disposition: PluginRevocationRecoveryDisposition.runtimeStillActiveAfterCompletion,
        guidance: 'The journal says deactivation completed but PluginManager '
            'reports the plugin active. Investigate a later activation, stale '
            'journal data, or a concurrency/ownership violation.',
      );
    }

    return PluginRevocationRecoveryFinding(
      record: record,
      pluginIsActive: active,
      disposition: record.status == PluginRevocationJournalStatus.reconciled ||
              record.status == PluginRevocationJournalStatus.completed ||
              record.status == PluginRevocationJournalStatus.rejected ||
              record.status == PluginRevocationJournalStatus.noOp ||
              record.status == PluginRevocationJournalStatus.unsupported
          ? PluginRevocationRecoveryDisposition.terminal
          : PluginRevocationRecoveryDisposition.manualReview,
      guidance: 'No automatic recovery action is available for this record.',
    );
  }
}

/// Host-verified resolution of an ambiguous journal entry.
///
/// Resolution only records the operator's conclusion. It never retries or
/// compensates plugin code. Any new attempt must use a new operation ID.
class PluginRevocationJournalResolver {
  final PluginRevocationJournalStore store;
  final DateTime Function() _clock;

  PluginRevocationJournalResolver({
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<PluginRevocationJournalRecord> resolve({
    required String idempotencyKey,
    required int expectedRevision,
    required String resolution,
  }) async {
    final normalized = resolution.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(resolution, 'resolution', 'Must not be empty.');
    }
    final current = await store.read(idempotencyKey);
    if (current == null) throw StateError('Revocation journal entry not found.');
    if (current.revision != expectedRevision) {
      throw StateError('Journal entry changed; reload before resolving.');
    }
    if (current.status != PluginRevocationJournalStatus.pending &&
        current.status != PluginRevocationJournalStatus.failed) {
      throw StateError('Only pending or failed entries can be reconciled.');
    }
    final replacement = current.nextRevision(
      status: PluginRevocationJournalStatus.reconciled,
      updatedAt: _clock().toUtc(),
      detail: 'Host-verified resolution: $normalized',
    );
    final updated = await store.compareAndSet(
      idempotencyKey: idempotencyKey,
      expectedRevision: expectedRevision,
      replacement: replacement,
    );
    if (!updated) throw StateError('Concurrent journal update detected.');
    return replacement;
  }
}

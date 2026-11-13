import 'dart:async';

import '../capabilities/capability_provider_health.dart';
import 'plugin_manager.dart';
import 'plugin_runtime_health.dart';

/// Host approval hook. Return false to reject a proposed lifecycle action.
typedef PluginRevocationApproval = FutureOr<bool> Function(
  CapabilityImpactDecision decision,
);

enum PluginRevocationExecutionStatus {
  completed,
  rejected,
  noOp,
  unsupported,
  alreadyCompleted,
  requiresReconciliation,
  failed,
}

final class PluginRevocationExecutionRecord {
  final String idempotencyKey;
  final String operationId;
  final String pluginId;
  final String providerOwnerId;
  final CapabilityImpactAction action;
  final PluginRevocationExecutionStatus status;
  final DateTime updatedAt;
  final String? detail;

  const PluginRevocationExecutionRecord({
    required this.idempotencyKey,
    required this.operationId,
    required this.pluginId,
    required this.providerOwnerId,
    required this.action,
    required this.status,
    required this.updatedAt,
    this.detail,
  });
}

/// Persistence boundary for idempotency records.
///
/// Implementations shared by multiple host processes must provide atomic
/// create-if-absent semantics for [writePending]. The in-memory store is only
/// suitable for a single process and tests.
abstract interface class PluginRevocationExecutionStore {
  Future<PluginRevocationExecutionRecord?> read(String idempotencyKey);

  /// Atomically inserts a pending record only when the key is absent.
  /// Returns false when another execution already owns the key.
  Future<bool> writePending(PluginRevocationExecutionRecord record);

  Future<void> complete(PluginRevocationExecutionRecord record);
}

class InMemoryPluginRevocationExecutionStore
    implements PluginRevocationExecutionStore {
  final Map<String, PluginRevocationExecutionRecord> _records = {};

  @override
  Future<PluginRevocationExecutionRecord?> read(String key) async =>
      _records[key];

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) async {
    if (_records.containsKey(record.idempotencyKey)) return false;
    _records[record.idempotencyKey] = record;
    return true;
  }

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) async {
    if (!_records.containsKey(record.idempotencyKey)) {
      throw StateError('No pending revocation record for this idempotency key.');
    }
    _records[record.idempotencyKey] = record;
  }
}

abstract interface class PluginRevocationAuditSink {
  Future<void> append(PluginRevocationExecutionRecord record);
}

class InMemoryPluginRevocationAuditSink implements PluginRevocationAuditSink {
  final List<PluginRevocationExecutionRecord> _records = [];

  List<PluginRevocationExecutionRecord> get records =>
      List<PluginRevocationExecutionRecord>.unmodifiable(_records);

  @override
  Future<void> append(PluginRevocationExecutionRecord record) async {
    _records.add(record);
  }
}

final class PluginRevocationExecutionReport {
  final String operationId;
  final List<PluginRevocationExecutionRecord> records;

  PluginRevocationExecutionReport({
    required this.operationId,
    required Iterable<PluginRevocationExecutionRecord> records,
  }) : records = List<PluginRevocationExecutionRecord>.unmodifiable(records);

  bool get succeeded => records.every((record) =>
      record.status == PluginRevocationExecutionStatus.completed ||
      record.status == PluginRevocationExecutionStatus.noOp ||
      record.status == PluginRevocationExecutionStatus.alreadyCompleted);
}

/// Executes approved provider-impact decisions through existing lifecycle APIs.
///
/// This coordinator deliberately does not infer plugin dependencies or
/// authorization. A host supplies the decisions, approval hook, durable
/// idempotency store, and audit sink. Suspension remains unsupported until
/// the plugin API defines a suspend/resume contract.
class PluginRevocationCoordinator {
  final PluginManager manager;
  final PluginRuntimeHealthRegistry? healthRegistry;
  final PluginRevocationExecutionStore executionStore;
  final PluginRevocationAuditSink auditSink;
  final PluginRevocationApproval approve;
  final DateTime Function() clock;

  PluginRevocationCoordinator({
    required this.manager,
    required this.executionStore,
    required this.auditSink,
    required this.approve,
    this.healthRegistry,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationExecutionReport> execute({
    required String operationId,
    required Iterable<CapabilityImpactDecision> decisions,
  }) async {
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty');
    }

    final ordered = decisions.toList()
      ..sort((a, b) {
        final plugin = a.pluginId.compareTo(b.pluginId);
        if (plugin != 0) return plugin;
        final provider = a.providerOwnerId.compareTo(b.providerOwnerId);
        if (provider != 0) return provider;
        return a.action.index.compareTo(b.action.index);
      });

    final records = <PluginRevocationExecutionRecord>[];
    await manager.runExclusiveLifecycleBatch(() async {
      for (final decision in ordered) {
        records.add(await _executeOne(normalizedOperationId, decision));
      }
    });
    return PluginRevocationExecutionReport(
      operationId: normalizedOperationId,
      records: records,
    );
  }

  Future<PluginRevocationExecutionRecord> _executeOne(
    String operationId,
    CapabilityImpactDecision decision,
  ) async {
    final pluginId = decision.pluginId.trim();
    final providerId = decision.providerOwnerId.trim();
    if (pluginId.isEmpty || providerId.isEmpty) {
      throw ArgumentError('Plugin and provider IDs must not be empty.');
    }

    final key = _key(operationId, pluginId, providerId, decision.action);
    final existing = await executionStore.read(key);
    if (existing != null) {
      if (existing.status == PluginRevocationExecutionStatus.completed ||
          existing.status == PluginRevocationExecutionStatus.noOp ||
          existing.status == PluginRevocationExecutionStatus.rejected ||
          existing.status == PluginRevocationExecutionStatus.unsupported) {
        return _record(
          operationId,
          key,
          decision,
          PluginRevocationExecutionStatus.alreadyCompleted,
          detail: 'An execution record already exists.',
        );
      }
      return _record(
        operationId,
        key,
        decision,
        PluginRevocationExecutionStatus.requiresReconciliation,
        detail: 'A previous execution was left pending or failed; inspect host state before retrying.',
      );
    }

    final pending = _record(
      operationId,
      key,
      decision,
      PluginRevocationExecutionStatus.requiresReconciliation,
      detail: 'Execution started; reconcile if the host process stops.',
    );
    if (!await executionStore.writePending(pending)) {
      return _record(
        operationId,
        key,
        decision,
        PluginRevocationExecutionStatus.requiresReconciliation,
        detail: 'Another executor claimed this idempotency key.',
      );
    }

    PluginRevocationExecutionRecord outcome;
    try {
      final approved = await approve(decision);
      if (!approved) {
        outcome = _record(
          operationId,
          key,
          decision,
          PluginRevocationExecutionStatus.rejected,
          detail: 'Host approval rejected the action.',
        );
      } else {
        outcome = await _apply(operationId, key, decision);
      }
    } catch (error) {
      outcome = _record(
        operationId,
        key,
        decision,
        PluginRevocationExecutionStatus.failed,
        detail: error.runtimeType.toString(),
      );
    }

    await executionStore.complete(outcome);
    await auditSink.append(outcome);
    return outcome;
  }

  Future<PluginRevocationExecutionRecord> _apply(
    String operationId,
    String key,
    CapabilityImpactDecision decision,
  ) async {
    final pluginId = decision.pluginId;
    switch (decision.action) {
      case CapabilityImpactAction.notify:
        return _record(
          operationId, key, decision, PluginRevocationExecutionStatus.noOp,
          detail: 'Notification is delegated to the host event consumer.',
        );
      case CapabilityImpactAction.markDegraded:
        final health = healthRegistry;
        if (health == null) {
          return _record(
            operationId, key, decision, PluginRevocationExecutionStatus.unsupported,
            detail: 'No PluginRuntimeHealthRegistry was configured.',
          );
        }
        final current = health.snapshotOf(pluginId);
        if (current == null) {
          health.observe(
            pluginId: pluginId,
            state: PluginRuntimeState.active,
            reason: 'Observed before provider degradation',
          );
        }
        final state = health.snapshotOf(pluginId)?.state;
        if (state == PluginRuntimeState.active) {
          health.transition(
            pluginId: pluginId,
            next: PluginRuntimeState.degraded,
            reason: 'Capability provider ${decision.providerOwnerId} is ${decision.providerState.name}',
          );
        } else if (state != PluginRuntimeState.degraded) {
          return _record(
            operationId, key, decision, PluginRevocationExecutionStatus.noOp,
            detail: 'Plugin is not active; current state is $state.',
          );
        }
        return _record(
          operationId, key, decision, PluginRevocationExecutionStatus.completed,
        );
      case CapabilityImpactAction.suspend:
        return _record(
          operationId, key, decision, PluginRevocationExecutionStatus.unsupported,
          detail: 'Suspend/resume is not yet part of the plugin lifecycle contract.',
        );
      case CapabilityImpactAction.deactivate:
        await manager.deactivate(pluginId);
        healthRegistry?.synchronize(
          pluginId: pluginId,
          state: PluginRuntimeState.stopped,
          reason: 'Deactivated by approved provider revocation operation $operationId',
        );
        return _record(
          operationId, key, decision, PluginRevocationExecutionStatus.completed,
        );
      case CapabilityImpactAction.recovered:
        final health = healthRegistry;
        if (health == null) {
          return _record(
            operationId, key, decision, PluginRevocationExecutionStatus.unsupported,
            detail: 'No PluginRuntimeHealthRegistry was configured.',
          );
        }
        final current = health.snapshotOf(pluginId);
        if (current?.state == PluginRuntimeState.degraded) {
          health.transition(
            pluginId: pluginId,
            next: PluginRuntimeState.active,
            reason: 'Capability provider ${decision.providerOwnerId} recovered',
          );
          return _record(
            operationId, key, decision, PluginRevocationExecutionStatus.completed,
          );
        }
        return _record(
          operationId, key, decision, PluginRevocationExecutionStatus.noOp,
          detail: 'Plugin is not degraded; no recovery transition was required.',
        );
    }
  }

  PluginRevocationExecutionRecord _record(
    String operationId,
    String key,
    CapabilityImpactDecision decision,
    PluginRevocationExecutionStatus status, {
    String? detail,
  }) =>
      PluginRevocationExecutionRecord(
        idempotencyKey: key,
        operationId: operationId,
        pluginId: decision.pluginId,
        providerOwnerId: decision.providerOwnerId,
        action: decision.action,
        status: status,
        updatedAt: clock().toUtc(),
        detail: detail,
      );

  String _key(
    String operationId,
    String pluginId,
    String providerId,
    CapabilityImpactAction action,
  ) => '${operationId.length}:$operationId'
      '${pluginId.length}:$pluginId'
      '${providerId.length}:$providerId'
      '${action.name}';
}

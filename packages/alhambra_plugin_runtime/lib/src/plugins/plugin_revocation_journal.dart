import '../capabilities/capability_provider_health.dart';
import 'plugin_revocation_coordinator.dart';

/// Durable outcome of one governed provider-impact decision.
enum PluginRevocationJournalStatus {
  pending,
  completed,
  rejected,
  noOp,
  unsupported,
  failed,
  reconciled,
}

/// Immutable, schema-versioned journal entry.
///
/// The journal stores host metadata only. It must never contain credentials,
/// provider payloads, plugin instances, or arbitrary exception messages.
final class PluginRevocationJournalRecord {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final String idempotencyKey;
  final String operationId;
  final String correlationId;
  final String pluginId;
  final String providerOwnerId;
  final CapabilityImpactAction action;
  final PluginRevocationJournalStatus status;
  final bool? approvalGranted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? detail;

  PluginRevocationJournalRecord({
    this.schemaVersion = currentSchemaVersion,
    required this.revision,
    required this.idempotencyKey,
    required this.operationId,
    required this.correlationId,
    required this.pluginId,
    required this.providerOwnerId,
    required this.action,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvalGranted,
    this.detail,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion',
          'Unsupported revocation journal schema.');
    }
    if (revision < 0) throw ArgumentError.value(revision, 'revision');
    for (final entry in <String, String>{
      'idempotencyKey': idempotencyKey,
      'operationId': operationId,
      'correlationId': correlationId,
      'pluginId': pluginId,
      'providerOwnerId': providerOwnerId,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, 'Must not be empty.');
      }
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt.');
    }
  }

  PluginRevocationJournalRecord nextRevision({
    required PluginRevocationJournalStatus status,
    required DateTime updatedAt,
    bool? approvalGranted,
    String? detail,
  }) =>
      PluginRevocationJournalRecord(
        schemaVersion: schemaVersion,
        revision: revision + 1,
        idempotencyKey: idempotencyKey,
        operationId: operationId,
        correlationId: correlationId,
        pluginId: pluginId,
        providerOwnerId: providerOwnerId,
        action: action,
        status: status,
        approvalGranted: approvalGranted ?? this.approvalGranted,
        createdAt: createdAt,
        updatedAt: updatedAt.isBefore(createdAt) ? createdAt : updatedAt,
        detail: detail,
      );
}

/// Persistence contract for revocation journaling.
///
/// Production adapters must implement createIfAbsent and compareAndSet as
/// atomic transactions/conditional writes across all runtime processes.
abstract interface class PluginRevocationJournalStore {
  Future<PluginRevocationJournalRecord?> read(String idempotencyKey);
  Future<List<PluginRevocationJournalRecord>> readAll();

  /// Atomically creates revision 0 only if the key does not already exist.
  Future<bool> createIfAbsent(PluginRevocationJournalRecord record);

  /// Atomically replaces a record iff its current revision matches
  /// [expectedRevision]. The replacement must have revision + 1.
  Future<bool> compareAndSet({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalRecord replacement,
  });
}

/// Single-process reference store. Not crash durable or multi-process safe.
class InMemoryPluginRevocationJournalStore
    implements PluginRevocationJournalStore {
  final Map<String, PluginRevocationJournalRecord> _records = {};

  @override
  Future<PluginRevocationJournalRecord?> read(String key) async =>
      _records[key];

  @override
  Future<List<PluginRevocationJournalRecord>> readAll() async =>
      List.unmodifiable(_records.values);

  @override
  Future<bool> createIfAbsent(PluginRevocationJournalRecord record) async {
    if (record.revision != 0 ||
        record.status != PluginRevocationJournalStatus.pending) {
      throw ArgumentError('A new journal entry must be pending at revision 0.');
    }
    if (_records.containsKey(record.idempotencyKey)) return false;
    _records[record.idempotencyKey] = record;
    return true;
  }

  @override
  Future<bool> compareAndSet({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalRecord replacement,
  }) async {
    final current = _records[idempotencyKey];
    if (current == null || current.revision != expectedRevision) return false;
    if (replacement.idempotencyKey != idempotencyKey ||
        replacement.revision != expectedRevision + 1) {
      throw ArgumentError('Replacement key/revision does not match CAS request.');
    }
    _records[idempotencyKey] = replacement;
    return true;
  }
}


/// Bridges the existing governed execution coordinator to the durable journal.
///
/// Supply a host correlation-ID resolver so provider events, revocation
/// decisions, lifecycle operations, and audit events can share one trace.
class JournalBackedPluginRevocationExecutionStore
    implements PluginRevocationExecutionStore {
  final PluginRevocationJournalStore journal;
  final String Function(PluginRevocationExecutionRecord record)
      correlationIdFor;

  JournalBackedPluginRevocationExecutionStore({
    required this.journal,
    required this.correlationIdFor,
  });

  @override
  Future<PluginRevocationExecutionRecord?> read(String idempotencyKey) async {
    final entry = await journal.read(idempotencyKey);
    if (entry == null) return null;
    return PluginRevocationExecutionRecord(
      idempotencyKey: entry.idempotencyKey,
      operationId: entry.operationId,
      pluginId: entry.pluginId,
      providerOwnerId: entry.providerOwnerId,
      action: entry.action,
      status: _executionStatus(entry.status),
      updatedAt: entry.updatedAt,
      detail: entry.detail,
    );
  }

  @override
  Future<bool> writePending(PluginRevocationExecutionRecord record) {
    if (record.status !=
        PluginRevocationExecutionStatus.requiresReconciliation) {
      throw ArgumentError('Initial journal records must be pending.');
    }
    return journal.createIfAbsent(PluginRevocationJournalRecord(
      revision: 0,
      idempotencyKey: record.idempotencyKey,
      operationId: record.operationId,
      correlationId: correlationIdFor(record).trim(),
      pluginId: record.pluginId,
      providerOwnerId: record.providerOwnerId,
      action: record.action,
      status: PluginRevocationJournalStatus.pending,
      createdAt: record.updatedAt,
      updatedAt: record.updatedAt,
      detail: record.detail,
    ));
  }

  @override
  Future<void> complete(PluginRevocationExecutionRecord record) async {
    final current = await journal.read(record.idempotencyKey);
    if (current == null ||
        current.status != PluginRevocationJournalStatus.pending) {
      throw StateError('No pending journal entry exists for this operation.');
    }
    final replacement = current.nextRevision(
      status: _journalStatus(record.status),
      updatedAt: record.updatedAt,
      detail: record.detail,
    );
    final updated = await journal.compareAndSet(
      idempotencyKey: record.idempotencyKey,
      expectedRevision: current.revision,
      replacement: replacement,
    );
    if (!updated) throw StateError('Concurrent journal update detected.');
  }

  PluginRevocationExecutionStatus _executionStatus(
    PluginRevocationJournalStatus status,
  ) =>
      switch (status) {
        PluginRevocationJournalStatus.pending ||
        PluginRevocationJournalStatus.reconciled =>
          PluginRevocationExecutionStatus.requiresReconciliation,
        PluginRevocationJournalStatus.completed =>
          PluginRevocationExecutionStatus.completed,
        PluginRevocationJournalStatus.rejected =>
          PluginRevocationExecutionStatus.rejected,
        PluginRevocationJournalStatus.noOp =>
          PluginRevocationExecutionStatus.noOp,
        PluginRevocationJournalStatus.unsupported =>
          PluginRevocationExecutionStatus.unsupported,
        PluginRevocationJournalStatus.failed =>
          PluginRevocationExecutionStatus.failed,
      };

  PluginRevocationJournalStatus _journalStatus(
    PluginRevocationExecutionStatus status,
  ) =>
      switch (status) {
        PluginRevocationExecutionStatus.completed =>
          PluginRevocationJournalStatus.completed,
        PluginRevocationExecutionStatus.rejected =>
          PluginRevocationJournalStatus.rejected,
        PluginRevocationExecutionStatus.noOp =>
          PluginRevocationJournalStatus.noOp,
        PluginRevocationExecutionStatus.unsupported =>
          PluginRevocationJournalStatus.unsupported,
        PluginRevocationExecutionStatus.failed =>
          PluginRevocationJournalStatus.failed,
        PluginRevocationExecutionStatus.requiresReconciliation =>
          PluginRevocationJournalStatus.pending,
        PluginRevocationExecutionStatus.alreadyCompleted =>
          PluginRevocationJournalStatus.completed,
      };
}

import '../capabilities/capability_provider_health.dart';

/// Durable state of one governed provider-impact action.
enum PluginRevocationJournalStatus { pending, completed, rejected, unsupported, failed, reconciledApplied, retryAuthorized, manualReview }

/// Versioned journal entry. Persist adapters should store enum names (not ordinals).
final class PluginRevocationJournalEntry {
  static const int currentSchemaVersion = 1;
  final int schemaVersion;
  final String idempotencyKey, operationId, pluginId, providerOwnerId;
  final CapabilityImpactAction action;
  final PluginRevocationJournalStatus status;
  final int revision;
  final DateTime createdAt, updatedAt;
  final String? correlationId, detail;

  PluginRevocationJournalEntry({
    this.schemaVersion = currentSchemaVersion,
    required this.idempotencyKey, required this.operationId,
    required this.pluginId, required this.providerOwnerId,
    required this.action, required this.status, required this.revision,
    required this.createdAt, required this.updatedAt,
    this.correlationId, this.detail,
  }) {
    if (schemaVersion < 1) throw ArgumentError.value(schemaVersion, 'schemaVersion');
    for (final field in [idempotencyKey, operationId, pluginId, providerOwnerId]) {
      if (field.trim().isEmpty) throw ArgumentError('Journal identity fields must not be empty.');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (updatedAt.isBefore(createdAt)) throw ArgumentError('updatedAt precedes createdAt');
  }

  bool get requiresReconciliation =>
      status == PluginRevocationJournalStatus.pending ||
      status == PluginRevocationJournalStatus.failed ||
      status == PluginRevocationJournalStatus.retryAuthorized ||
      status == PluginRevocationJournalStatus.manualReview;

  PluginRevocationJournalEntry next({
    required PluginRevocationJournalStatus status,
    required DateTime at,
    String? detail,
  }) => PluginRevocationJournalEntry(
    schemaVersion: schemaVersion, idempotencyKey: idempotencyKey,
    operationId: operationId, pluginId: pluginId, providerOwnerId: providerOwnerId,
    action: action, status: status, revision: revision + 1,
    createdAt: createdAt,
    updatedAt: at.toUtc().isBefore(createdAt) ? createdAt : at.toUtc(),
    correlationId: correlationId, detail: detail,
  );
}

/// Atomic persistence boundary. Production implementations must provide
/// linearizable insert-if-absent and compare-and-set across host processes.
abstract interface class PluginRevocationJournalStore {
  Future<PluginRevocationJournalEntry?> read(String idempotencyKey);
  Future<List<PluginRevocationJournalEntry>> readAll();
  Future<bool> insertIfAbsent(PluginRevocationJournalEntry entry);
  Future<bool> compareAndSet({
    required String idempotencyKey,
    required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  });
}

/// Reference store for tests and single-process development only.
class InMemoryPluginRevocationJournalStore implements PluginRevocationJournalStore {
  final Map<String, PluginRevocationJournalEntry> _entries = {};
  @override
  Future<PluginRevocationJournalEntry?> read(String key) async => _entries[key];
  @override
  Future<List<PluginRevocationJournalEntry>> readAll() async =>
      List.unmodifiable(_entries.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  @override
  Future<bool> insertIfAbsent(PluginRevocationJournalEntry entry) async {
    if (_entries.containsKey(entry.idempotencyKey)) return false;
    _entries[entry.idempotencyKey] = entry;
    return true;
  }
  @override
  Future<bool> compareAndSet({
    required String idempotencyKey, required int expectedRevision,
    required PluginRevocationJournalEntry replacement,
  }) async {
    final current = _entries[idempotencyKey];
    if (current == null || current.revision != expectedRevision ||
        replacement.revision != expectedRevision + 1 ||
        replacement.idempotencyKey != idempotencyKey) return false;
    _entries[idempotencyKey] = replacement;
    return true;
  }
}

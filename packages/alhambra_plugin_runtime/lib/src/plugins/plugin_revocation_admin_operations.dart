import 'plugin_revocation_journal.dart';
import 'plugin_revocation_operations.dart';
import 'plugin_revocation_operator_actions.dart';
import 'plugin_revocation_outbox.dart';

/// Authenticated operator identity supplied by the embedding host.
final class PluginRevocationOperationsPrincipal {
  final String actorId;

  PluginRevocationOperationsPrincipal({required this.actorId}) {
    if (actorId.trim().isEmpty) {
      throw ArgumentError.value(actorId, 'actorId');
    }
  }
}

/// Legacy compatibility hook for hosts whose adapters predate persisted scope.
/// New adapters persist scopeId directly; administrative inspection uses that
/// immutable value and does not infer ownership from plugin identifiers.
@Deprecated('Use persisted scopeId on journal and outbox records.')
abstract interface class PluginRevocationOperationsScopeResolver {
  Future<String?> resolveJournalScope(
    PluginRevocationJournalEntry entry,
  );

  Future<String?> resolveOutboxScope(
    PluginRevocationOutboxMessage message,
  );
}

/// Host authorization port for operational inspection.
abstract interface class PluginRevocationOperationsAuthorizer {
  Future<bool> canInspect({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  });
}

enum PluginRevocationOperationsAccessDecision { allowed, denied }

/// Security audit record for an administrative inspection attempt.
final class PluginRevocationOperationsAccessAudit {
  final String actorId;
  final String scopeId;
  final PluginRevocationOperationsAccessDecision decision;
  final String? denialCode;
  final DateTime occurredAt;
  /// Optional operation metadata for paginated administrative reads.
  final String? resource;
  final int? pageSize;
  final bool? continuationRequested;
  final String? queryFingerprint;

  PluginRevocationOperationsAccessAudit({
    required this.actorId,
    required this.scopeId,
    required this.decision,
    required this.occurredAt,
    this.denialCode,
    this.resource,
    this.pageSize,
    this.continuationRequested,
    this.queryFingerprint,
  }) {
    if (actorId.trim().isEmpty || scopeId.trim().isEmpty) {
      throw ArgumentError('Access audit actor and scope are required.');
    }
    if (pageSize != null && (pageSize! < 1 || pageSize! > 200)) {
      throw ArgumentError.value(pageSize, 'pageSize');
    }
    if (queryFingerprint != null && queryFingerprint!.trim().isEmpty) {
      throw ArgumentError.value(queryFingerprint, 'queryFingerprint');
    }
    if (decision == PluginRevocationOperationsAccessDecision.allowed &&
        denialCode != null) {
      throw ArgumentError('Allowed access audit cannot contain a denial code.');
    }
    if (decision == PluginRevocationOperationsAccessDecision.denied &&
        (denialCode == null || denialCode!.trim().isEmpty)) {
      throw ArgumentError('Denied access audit requires a denial code.');
    }
  }
}

/// Host-owned durable audit sink. Production hosts should persist these
/// records independently of the revocation outbox being inspected.
abstract interface class PluginRevocationOperationsAccessAuditStore {
  Future<void> append(PluginRevocationOperationsAccessAudit audit);
}

final class InMemoryPluginRevocationOperationsAccessAuditStore
    implements PluginRevocationOperationsAccessAuditStore {
  final List<PluginRevocationOperationsAccessAudit> _records = [];

  @override
  Future<void> append(PluginRevocationOperationsAccessAudit audit) async {
    _records.add(audit);
  }

  List<PluginRevocationOperationsAccessAudit> get records =>
      List.unmodifiable(_records);
}

final class PluginRevocationAdminOperationsSnapshot {
  final String scopeId;
  final PluginRevocationOperationsSnapshot operations;
  final List<PluginRevocationOperatorAction> operatorActions;

  PluginRevocationAdminOperationsSnapshot({
    required this.scopeId,
    required this.operations,
    required Iterable<PluginRevocationOperatorAction> operatorActions,
  }) : operatorActions = List.unmodifiable(operatorActions);
}

/// Authenticated, scope-filtered administrative read boundary.
///
/// Authorization is checked before reading operational state. Journal and
/// outbox ownership is enforced using persisted scopeId fields. Operator replay
/// history is filtered by its persisted scopeId. Access
/// decisions are audited before the service returns data or throws denial.
final class PluginRevocationAdminOperationsService {
  final PluginRevocationOperationsService operations;
  final PluginRevocationOperatorActionInspectionStore operatorActionStore;
  @Deprecated('Persisted record scopeId is authoritative.')
  final PluginRevocationOperationsScopeResolver? scopeResolver;
  final PluginRevocationOperationsAuthorizer authorizer;
  final PluginRevocationOperationsAccessAuditStore accessAuditStore;
  final DateTime Function() clock;

  PluginRevocationAdminOperationsService({
    required this.operations,
    required this.operatorActionStore,
    this.scopeResolver,
    required this.authorizer,
    required this.accessAuditStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAdminOperationsSnapshot> inspect({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
    final now = clock().toUtc();
    final allowed = await authorizer.canInspect(
      principal: principal,
      scopeId: scopeId,
    );

    await accessAuditStore.append(PluginRevocationOperationsAccessAudit(
      actorId: principal.actorId,
      scopeId: scopeId,
      decision: allowed
          ? PluginRevocationOperationsAccessDecision.allowed
          : PluginRevocationOperationsAccessDecision.denied,
      denialCode: allowed ? null : 'operations_inspection_denied',
      occurredAt: now,
    ));

    if (!allowed) {
      throw const PluginRevocationOperationsAccessDeniedException();
    }

    final results = await Future.wait<Object>([
      operations.inspect(),
      operatorActionStore.readOperatorActions(),
    ]);
    final raw = results[0] as PluginRevocationOperationsSnapshot;
    final actions = results[1] as List<PluginRevocationOperatorAction>;

    final journals = raw.journalEntries
        .where((entry) => entry.scopeId == scopeId)
        .toList(growable: false);
    final messages = raw.outboxMessages
        .where((message) => message.event.scopeId == scopeId)
        .toList(growable: false);
    final scopedActions = actions
        .where((action) => action.scopeId == scopeId)
        .toList()
      ..sort((a, b) {
        final occurred = b.occurredAt.compareTo(a.occurredAt);
        return occurred != 0 ? occurred : a.actionId.compareTo(b.actionId);
      });

    final journalCounts = <PluginRevocationJournalStatus, int>{
      for (final status in PluginRevocationJournalStatus.values)
        status: journals.where((entry) => entry.status == status).length,
    };
    final outboxCounts = <PluginRevocationOutboxState, int>{
      for (final state in PluginRevocationOutboxState.values)
        state: messages.where((message) => message.state == state).length,
    };
    final scopedSnapshot = PluginRevocationOperationsSnapshot(
      capturedAt: raw.capturedAt,
      journalEntries: journals,
      outboxMessages: messages,
      journalCounts: journalCounts,
      outboxCounts: outboxCounts,
      unresolvedJournalEntries:
          journals.where((entry) => entry.requiresReconciliation).length,
      overduePendingMessages: messages.where((message) =>
          message.state == PluginRevocationOutboxState.pending &&
          !message.nextAttemptAt.isAfter(raw.capturedAt)).length,
      expiredLeases: messages.where((message) =>
          message.state == PluginRevocationOutboxState.leased &&
          message.leaseUntil != null &&
          !message.leaseUntil!.isAfter(raw.capturedAt)).length,
    );

    return PluginRevocationAdminOperationsSnapshot(
      scopeId: scopeId,
      operations: scopedSnapshot,
      operatorActions: scopedActions,
    );
  }
}

final class PluginRevocationOperationsAccessDeniedException
    implements Exception {
  const PluginRevocationOperationsAccessDeniedException();

  @override
  String toString() => 'Plugin revocation operations inspection denied.';
}

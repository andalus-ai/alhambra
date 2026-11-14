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

/// Resolves record ownership from authoritative host data.
///
/// Journal and outbox records predate scope-aware persistence. Until those
/// schemas carry scope IDs, hosts must resolve ownership using trusted
/// operation/resource metadata rather than caller-supplied identifiers.
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

  PluginRevocationOperationsAccessAudit({
    required this.actorId,
    required this.scopeId,
    required this.decision,
    required this.occurredAt,
    this.denialCode,
  }) {
    if (actorId.trim().isEmpty || scopeId.trim().isEmpty) {
      throw ArgumentError('Access audit actor and scope are required.');
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
/// outbox ownership is resolved through host-provided authoritative metadata.
/// Operator replay history is filtered by the persisted scopeId. Access
/// decisions are audited before the service returns data or throws denial.
final class PluginRevocationAdminOperationsService {
  final PluginRevocationOperationsService operations;
  final PluginRevocationOperatorActionInspectionStore operatorActionStore;
  final PluginRevocationOperationsScopeResolver scopeResolver;
  final PluginRevocationOperationsAuthorizer authorizer;
  final PluginRevocationOperationsAccessAuditStore accessAuditStore;
  final DateTime Function() clock;

  PluginRevocationAdminOperationsService({
    required this.operations,
    required this.operatorActionStore,
    required this.scopeResolver,
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

    final journalScopes = await Future.wait(
      raw.journalEntries.map(scopeResolver.resolveJournalScope),
    );
    final outboxScopes = await Future.wait(
      raw.outboxMessages.map(scopeResolver.resolveOutboxScope),
    );
    final journals = <PluginRevocationJournalEntry>[];
    for (var index = 0; index < raw.journalEntries.length; index++) {
      if (journalScopes[index] == scopeId) {
        journals.add(raw.journalEntries[index]);
      }
    }
    final messages = <PluginRevocationOutboxMessage>[];
    for (var index = 0; index < raw.outboxMessages.length; index++) {
      if (outboxScopes[index] == scopeId) {
        messages.add(raw.outboxMessages[index]);
      }
    }
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

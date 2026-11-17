import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'plugin_revocation_admin_operations.dart';
import 'plugin_revocation_journal.dart';
import 'plugin_revocation_operator_actions.dart';
import 'plugin_revocation_outbox.dart';
import 'plugin_revocation_scoped_queries.dart';

/// Identifies the data family inspected by a paginated admin request.
enum PluginRevocationAdminPageResource {
  journal,
  outbox,
  operatorActions,
}

/// A page returned only after the requested scope has been authorized
/// and the access decision has been durably audited.
final class PluginRevocationAdminPage<T> {
  final String scopeId;
  final PluginRevocationAdminPageResource resource;
  final PluginRevocationScopedPage<T> page;

  const PluginRevocationAdminPage({
    required this.scopeId,
    required this.resource,
    required this.page,
  });
}

/// Authorized application boundary for database-native revocation pages.
///
/// The host supplies authentication-derived principals, authorization policy,
/// durable access auditing and a scoped query adapter. This service never
/// falls back to read-all/in-memory filtering. The access audit is appended
/// before the page query; if auditing fails, the query is not executed.
final class PluginRevocationAdminPageService {
  final PluginRevocationOperationsAuthorizer authorizer;
  final PluginRevocationOperationsAccessAuditStore accessAuditStore;
  final PluginRevocationScopedQueryStore? queryStore;
  final DateTime Function() clock;

  PluginRevocationAdminPageService({
    required this.authorizer,
    required this.accessAuditStore,
    required this.queryStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<PluginRevocationAdminPage<PluginRevocationJournalEntry>>
      journalPage({
    required PluginRevocationOperationsPrincipal principal,
    required PluginRevocationJournalPageQuery query,
  }) async {
    await _authorizeAndAudit(
      principal: principal,
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.journal,
      pageSize: query.pageSize,
      hasCursor: query.cursor != null,
      fingerprint: _fingerprint([
        'journal',
        query.scopeId,
        query.fromInclusive?.toUtc().toIso8601String() ?? '',
        query.toExclusive?.toUtc().toIso8601String() ?? '',
        query.pageSize.toString(),
        ...query.statuses.map((value) => value.name),
      ]),
    );
    final store = _requireStore();
    final page = await store.queryJournalPage(query);
    return PluginRevocationAdminPage(
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.journal,
      page: page,
    );
  }

  Future<PluginRevocationAdminPage<PluginRevocationOutboxMessage>>
      outboxPage({
    required PluginRevocationOperationsPrincipal principal,
    required PluginRevocationOutboxPageQuery query,
  }) async {
    await _authorizeAndAudit(
      principal: principal,
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.outbox,
      pageSize: query.pageSize,
      hasCursor: query.cursor != null,
      fingerprint: _fingerprint([
        'outbox',
        query.scopeId,
        query.fromInclusive?.toUtc().toIso8601String() ?? '',
        query.toExclusive?.toUtc().toIso8601String() ?? '',
        query.pageSize.toString(),
        ...query.states.map((value) => value.name),
      ]),
    );
    final store = _requireStore();
    final page = await store.queryOutboxPage(query);
    return PluginRevocationAdminPage(
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.outbox,
      page: page,
    );
  }

  Future<PluginRevocationAdminPage<PluginRevocationOperatorAction>>
      operatorActionPage({
    required PluginRevocationOperationsPrincipal principal,
    required PluginRevocationOperatorActionPageQuery query,
  }) async {
    await _authorizeAndAudit(
      principal: principal,
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.operatorActions,
      pageSize: query.pageSize,
      hasCursor: query.cursor != null,
      fingerprint: _fingerprint([
        'operatorActions',
        query.scopeId,
        query.fromInclusive?.toUtc().toIso8601String() ?? '',
        query.toExclusive?.toUtc().toIso8601String() ?? '',
        query.pageSize.toString(),
      ]),
    );
    final store = _requireStore();
    final page = await store.queryOperatorActionPage(query);
    return PluginRevocationAdminPage(
      scopeId: query.scopeId,
      resource: PluginRevocationAdminPageResource.operatorActions,
      page: page,
    );
  }

  PluginRevocationScopedQueryStore _requireStore() {
    final store = queryStore;
    if (store == null) {
      throw const PluginRevocationScopedQueryUnavailableException();
    }
    return store;
  }

  Future<void> _authorizeAndAudit({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
    required PluginRevocationAdminPageResource resource,
    required int pageSize,
    required bool hasCursor,
    required String fingerprint,
  }) async {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId');
    }
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
      denialCode: allowed ? null : 'operations_page_inspection_denied',
      occurredAt: clock().toUtc(),
      resource: resource.name,
      pageSize: pageSize,
      continuationRequested: hasCursor,
      queryFingerprint: fingerprint,
    ));
    if (!allowed) {
      throw const PluginRevocationOperationsAccessDeniedException();
    }
  }

  String _fingerprint(List<String> components) {
    final canonical = jsonEncode(components);
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

/// Raised when the host has not configured a database-native scoped query
/// adapter. The service intentionally does not fall back to read-all queries.
final class PluginRevocationScopedQueryUnavailableException
    implements Exception {
  const PluginRevocationScopedQueryUnavailableException();

  @override
  String toString() =>
      'Database-native scoped revocation queries are not configured.';
}

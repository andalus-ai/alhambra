import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

final class _ScopeResolver implements PluginRevocationReplayScopeResolver {
  final String? scopeId;
  _ScopeResolver(this.scopeId);

  @override
  Future<String?> resolveScopeId(String eventId) async => scopeId;
}

final class _Authorizer implements PluginRevocationReplayAuthorizer {
  final bool allowed;
  var calls = 0;
  _Authorizer(this.allowed);

  @override
  Future<bool> canReplay({
    required PluginRevocationReplayPrincipal principal,
    required String targetEventId,
  }) async {
    calls++;
    return allowed;
  }
}

final class _ApprovalVerifier implements PluginRevocationReplayApprovalVerifier {
  final bool approved;
  var calls = 0;
  _ApprovalVerifier(this.approved);

  @override
  Future<bool> isApproved({
    required PluginRevocationReplayPrincipal principal,
    required String targetEventId,
    required String approvalReference,
  }) async {
    calls++;
    return approved;
  }
}

final class _ReplayStore implements PluginRevocationDeadLetterReplayStore {
  PluginRevocationReplayRequest? request;
  var calls = 0;

  @override
  Future<PluginRevocationReplayResult?> replayDeadLetter(
    PluginRevocationReplayRequest request,
  ) async {
    this.request = request;
    calls++;
    return null;
  }
}

void main() {
  const target = 'outbox-event-1';
  final principal = PluginRevocationReplayPrincipal(
    actorId: 'operator-7',
    scopeId: 'tenant-blue',
  );

  test('authorizes scope, permission and approval before persistence', () async {
    final store = _ReplayStore();
    final authorizer = _Authorizer(true);
    final approval = _ApprovalVerifier(true);
    final service = PluginRevocationReplayCommandService(
      store: store,
      scopeResolver: _ScopeResolver('tenant-blue'),
      authorizer: authorizer,
      approvalVerifier: approval,
      clock: () => DateTime.utc(2026, 11, 14),
    );

    await service.replay(
      actionId: 'action-1',
      principal: principal,
      targetEventId: target,
      reason: 'Approved recovery after publisher outage',
      approvalReference: 'change-42',
    );

    expect(store.calls, 1);
    expect(store.request?.actorId, 'operator-7');
    expect(store.request?.scopeId, 'tenant-blue');
    expect(store.request?.targetEventId, target);
    expect(store.request?.approvalReference, 'change-42');
    expect(store.request?.occurredAt, DateTime.utc(2026, 11, 14));
    expect(authorizer.calls, 1);
    expect(approval.calls, 1);
  });

  test('rejects cross-scope target before permission and store calls', () async {
    final store = _ReplayStore();
    final authorizer = _Authorizer(true);
    final approval = _ApprovalVerifier(true);
    final service = PluginRevocationReplayCommandService(
      store: store,
      scopeResolver: _ScopeResolver('tenant-red'),
      authorizer: authorizer,
      approvalVerifier: approval,
    );

    await expectLater(
      service.replay(
        actionId: 'action-2',
        principal: principal,
        targetEventId: target,
        reason: 'Cross-scope attempt',
        approvalReference: 'change-43',
      ),
      throwsA(isA<PluginRevocationReplayDeniedException>().having(
        (error) => error.reason,
        'reason',
        PluginRevocationReplayDenialReason.scopeMismatch,
      )),
    );
    expect(authorizer.calls, 0);
    expect(approval.calls, 0);
    expect(store.calls, 0);
  });

  test('rejects an operator without replay permission', () async {
    final store = _ReplayStore();
    final authorizer = _Authorizer(false);
    final approval = _ApprovalVerifier(true);
    final service = PluginRevocationReplayCommandService(
      store: store,
      scopeResolver: _ScopeResolver('tenant-blue'),
      authorizer: authorizer,
      approvalVerifier: approval,
    );

    await expectLater(
      service.replay(
        actionId: 'action-3',
        principal: principal,
        targetEventId: target,
        reason: 'Unauthorized attempt',
        approvalReference: 'change-44',
      ),
      throwsA(isA<PluginRevocationReplayDeniedException>().having(
        (error) => error.reason,
        'reason',
        PluginRevocationReplayDenialReason.permissionDenied,
      )),
    );
    expect(approval.calls, 0);
    expect(store.calls, 0);
  });

  test('rejects unapproved change reference', () async {
    final store = _ReplayStore();
    final authorizer = _Authorizer(true);
    final approval = _ApprovalVerifier(false);
    final service = PluginRevocationReplayCommandService(
      store: store,
      scopeResolver: _ScopeResolver('tenant-blue'),
      authorizer: authorizer,
      approvalVerifier: approval,
    );

    await expectLater(
      service.replay(
        actionId: 'action-4',
        principal: principal,
        targetEventId: target,
        reason: 'Unapproved attempt',
        approvalReference: 'change-45',
      ),
      throwsA(isA<PluginRevocationReplayDeniedException>().having(
        (error) => error.reason,
        'reason',
        PluginRevocationReplayDenialReason.approvalRejected,
      )),
    );
    expect(authorizer.calls, 1);
    expect(approval.calls, 1);
    expect(store.calls, 0);
  });
}

import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final principal = PluginRevocationOperationsPrincipal(actorId: 'operator-1');

  test('creates and verifies a signed checkpoint with an external store', () async {
    final chain = _ChainStore();
    final external = _CheckpointStore();
    final service = _service(chain, external);

    final checkpoint = await service.createCheckpoint(
      principal: principal,
      scopeId: 'workspace-a',
    );

    expect(checkpoint.sequence, 3);
    expect(checkpoint.headHash, _hash('a'));
    expect(checkpoint.signingKeyId, 'test-key');
    expect(external.latest, same(checkpoint));

    final verified = await service.verifyLatest(
      principal: principal,
      scopeId: 'workspace-a',
    );
    expect(verified, same(checkpoint));
  });

  test('rejects a checkpoint when its signature is invalid', () async {
    final external = _CheckpointStore();
    final service = _service(
      _ChainStore(),
      external,
      verifier: _Verifier(valid: false),
    );
    await service.createCheckpoint(principal: principal, scopeId: 'workspace-a');

    await expectLater(
      service.verifyLatest(principal: principal, scopeId: 'workspace-a'),
      throwsA(isA<PluginRevocationAccessAuditCheckpointIntegrityException>()),
    );
  });

  test('rejects an externally anchored head missing from the local chain',
      () async {
    final external = _CheckpointStore();
    final service = _service(_ChainStore(containsHead: false), external);
    await service.createCheckpoint(principal: principal, scopeId: 'workspace-a');

    await expectLater(
      service.verifyLatest(principal: principal, scopeId: 'workspace-a'),
      throwsA(isA<PluginRevocationAccessAuditCheckpointIntegrityException>()),
    );
  });

  test('fails closed when checkpoint management is not authorized', () async {
    final service = _service(_ChainStore(), _CheckpointStore(),
        authorizer: _Authorizer(allowed: false));
    await expectLater(
      service.createCheckpoint(principal: principal, scopeId: 'workspace-a'),
      throwsA(isA<PluginRevocationAccessAuditCheckpointDeniedException>()),
    );
  });

  test('checkpoint digest covers signature and canonical metadata', () {
    final checkpoint = PluginRevocationAccessAuditCheckpoint(
      scopeId: 'workspace-a',
      sequence: 3,
      headHash: _hash('a'),
      createdAt: DateTime.utc(2026, 1, 1),
      signingKeyId: 'test-key',
      signature: 'signature',
    );
    final changed = PluginRevocationAccessAuditCheckpoint(
      scopeId: 'workspace-a',
      sequence: 3,
      headHash: _hash('a'),
      createdAt: DateTime.utc(2026, 1, 1),
      signingKeyId: 'test-key',
      signature: 'different-signature',
    );
    expect(
      PluginRevocationAccessAuditCheckpointCodec.digest(checkpoint),
      isNot(PluginRevocationAccessAuditCheckpointCodec.digest(changed)),
    );
  });
}

PluginRevocationAccessAuditCheckpointService _service(
  _ChainStore chain,
  _CheckpointStore external, {
  _Verifier verifier = const _Verifier(),
  _Authorizer authorizer = const _Authorizer(),
}) =>
    PluginRevocationAccessAuditCheckpointService(
      chainStore: chain,
      chainVerifier: chain,
      checkpointStore: external,
      signer: const _Signer(),
      signatureVerifier: verifier,
      authorizer: authorizer,
      clock: () => DateTime.utc(2026, 1, 1),
    );

String _hash(String value) => value.padLeft(64, '0');

final class _ChainStore
    implements
        PluginRevocationAccessAuditChainStore,
        PluginRevocationAccessAuditCheckpointChainVerifier {
  final bool containsHead;
  _ChainStore({this.containsHead = true});

  @override
  Future<PluginRevocationAccessAuditChainVerification>
      verifyAccessAuditChain({required String scopeId}) async =>
          PluginRevocationAccessAuditChainVerification(
            scopeId: scopeId,
            valid: true,
            entriesVerified: 3,
            headHash: _hash('a'),
          );

  @override
  Future<bool> containsVerifiedHead({
    required String scopeId,
    required int sequence,
    required String headHash,
  }) async =>
      containsHead && scopeId == 'workspace-a' && sequence == 3 &&
      headHash == _hash('a');
}

final class _CheckpointStore
    implements PluginRevocationAccessAuditCheckpointStore {
  PluginRevocationAccessAuditCheckpoint? latest;

  @override
  Future<PluginRevocationAccessAuditCheckpoint?> readLatest({
    required String scopeId,
  }) async =>
      latest?.scopeId == scopeId ? latest : null;

  @override
  Future<bool> append({
    required String? expectedPreviousDigest,
    required PluginRevocationAccessAuditCheckpoint checkpoint,
  }) async {
    final actual = latest == null
        ? null
        : PluginRevocationAccessAuditCheckpointCodec.digest(latest!);
    if (actual != expectedPreviousDigest) return false;
    latest = checkpoint;
    return true;
  }
}

final class _Signer implements PluginRevocationAccessAuditCheckpointSigner {
  const _Signer();

  @override
  String get keyId => 'test-key';

  @override
  Future<String> sign(String canonicalPayload) async => 'signed:$canonicalPayload';
}

final class _Verifier
    implements PluginRevocationAccessAuditCheckpointVerifier {
  final bool valid;
  const _Verifier({this.valid = true});

  @override
  Future<bool> verify({
    required String keyId,
    required String canonicalPayload,
    required String signature,
  }) async =>
      valid && keyId == 'test-key' && signature == 'signed:$canonicalPayload';
}

final class _Authorizer
    implements PluginRevocationAccessAuditCheckpointAuthorizer {
  final bool allowed;
  const _Authorizer({this.allowed = true});

  @override
  Future<bool> canManageAuditCheckpoint({
    required PluginRevocationOperationsPrincipal principal,
    required String scopeId,
  }) async =>
      allowed && principal.actorId == 'operator-1' && scopeId == 'workspace-a';
}

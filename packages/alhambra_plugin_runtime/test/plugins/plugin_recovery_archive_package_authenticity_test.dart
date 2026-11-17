import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Archive implements PluginLifecycleRecoveryJobArchive {
  final Map<String, PluginLifecycleRecoveryJobArchiveRecord> records = {};
  @override
  Future<PluginLifecycleRecoveryJobArchiveRecord?> read(String jobId) async => records[jobId];
  @override
  Future<bool> putIfAbsent(PluginLifecycleRecoveryJobArchiveRecord record) async {
    if (records.containsKey(record.job.jobId)) return false;
    records[record.job.jobId] = record;
    return true;
  }
}

final class _Digest implements PluginLifecycleRecoveryJobDigestProvider {
  @override
  Future<String> digest({required String algorithm, required String canonicalPayload}) async =>
      algorithm + '-' + canonicalPayload.hashCode.toString() + '-' + canonicalPayload.length.toString();
}

final class _Signer implements PluginRecoveryArchivePackageSigner {
  @override
  Future<String> sign({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
  }) async => algorithm + ':' + keyId + ':' + canonicalPayload.hashCode.toString();
}

final class _SignatureVerifier implements PluginRecoveryArchivePackageSignatureVerifier {
  @override
  Future<bool> verify({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
    required String signature,
  }) async => signature == algorithm + ':' + keyId + ':' + canonicalPayload.hashCode.toString();
}

final class _TrustPolicy implements PluginRecoveryArchivePackageTrustPolicy {
  PluginRecoveryArchiveSignerTrustDecision decision =
      PluginRecoveryArchiveSignerTrustDecision.trusted;

  @override
  Future<PluginRecoveryArchiveSignerTrustAssessment> assess({
    required String producer,
    required String keyId,
    required String algorithm,
    required DateTime packageCreatedAt,
  }) async => PluginRecoveryArchiveSignerTrustAssessment(
    decision: decision,
    principalId: decision == PluginRecoveryArchiveSignerTrustDecision.trusted
        ? 'publisher:' + producer
        : null,
    reasonCode: decision.name,
  );
}

PluginLifecycleRecoveryJob _job() => PluginLifecycleRecoveryJob(
  jobId: 'job-a',
  idempotencyKey: 'key-a',
  operationId: 'operation-a',
  action: PluginRecoveryJobAction.resumeStartup,
  orderedPluginIds: const ['plugin.one'],
  steps: [PluginRecoveryJobStep(
    pluginId: 'plugin.one',
    ordinal: 0,
    status: PluginRecoveryJobStepStatus.completed,
    completedAt: DateTime.utc(2026, 11, 1, 0, 1),
  )],
  status: PluginRecoveryJobStatus.completed,
  revision: 2,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1, 0, 1),
);

Future<PluginRecoveryArchivePackage> _package(_Digest digest) async {
  final job = _job();
  final archivedAt = DateTime.utc(2026, 11, 1, 0, 2);
  const snapshotCodec = PluginLifecycleRecoveryJobSnapshotCodec();
  final recordDigest = await digest.digest(
    algorithm: 'record-test',
    canonicalPayload: snapshotCodec.encode(job, archivedAt: archivedAt),
  );
  final record = PluginLifecycleRecoveryJobArchiveRecord(
    job: job,
    archivedAt: archivedAt,
    integrity: PluginLifecycleRecoveryJobArchiveIntegrity(
      formatVersion: PluginLifecycleRecoveryJobSnapshotCodec.formatVersion,
      algorithm: 'record-test',
      digest: recordDigest,
    ),
  );
  return PluginRecoveryArchivePackageExporter(
    digestProvider: digest,
    digestAlgorithm: 'package-test',
  ).create(
    packageId: 'bundle-a',
    producer: 'test-host',
    createdAt: DateTime.utc(2026, 11, 2),
    records: [record],
  );
}

void main() {
  group('PluginRecoveryArchivePackage authenticity', () {
    test('signs and round-trips a detached signature envelope', () async {
      final digest = _Digest();
      final package = await _package(digest);
      final signed = await PluginRecoveryArchivePackageSigningService(
        signer: _Signer(),
      ).sign(
        archivePackage: package,
        algorithm: 'test-signature',
        keyId: 'publisher-key-1',
      );
      const codec = PluginRecoveryArchiveSignedPackageCodec();
      final decoded = codec.decode(codec.encode(signed));
      expect(decoded.archivePackage.manifest.packageId, 'bundle-a');
      expect(decoded.signature.keyId, 'publisher-key-1');
      expect(decoded.signature.value, signed.signature.value);
    });

    test('requires trusted signer and valid signature before archive import', () async {
      final digest = _Digest();
      final package = await _package(digest);
      final signed = await PluginRecoveryArchivePackageSigningService(
        signer: _Signer(),
      ).sign(
        archivePackage: package,
        algorithm: 'test-signature',
        keyId: 'publisher-key-1',
      );
      final trust = _TrustPolicy();
      final destination = _Archive();
      final authenticatedImporter = PluginRecoveryArchiveAuthenticatedPackageImporter(
        authenticityVerifier: PluginRecoveryArchivePackageAuthenticityVerifier(
          signatureVerifier: _SignatureVerifier(),
          trustPolicy: trust,
        ),
        packageImporter: PluginRecoveryArchivePackageImporter(
          destinationArchive: destination,
          digestProvider: digest,
        ),
      );

      final plan = await authenticatedImporter.inspect(signed);
      expect(plan.authenticity.disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.valid);
      expect(plan.canImport, isTrue);
      final report = await authenticatedImporter.importPackage(plan);
      expect(report.authenticity.isValid, isTrue);
      expect(report.importReport?.importedJobIds, ['job-a']);
      expect(destination.records.keys, ['job-a']);
    });

    test('rejects unknown, revoked, disallowed, and cryptographically invalid signatures', () async {
      final digest = _Digest();
      final package = await _package(digest);
      final signed = await PluginRecoveryArchivePackageSigningService(
        signer: _Signer(),
      ).sign(
        archivePackage: package,
        algorithm: 'test-signature',
        keyId: 'publisher-key-1',
      );
      final trust = _TrustPolicy();
      final verifier = PluginRecoveryArchivePackageAuthenticityVerifier(
        signatureVerifier: _SignatureVerifier(),
        trustPolicy: trust,
      );

      trust.decision = PluginRecoveryArchiveSignerTrustDecision.unknownSigner;
      expect((await verifier.verify(signed)).disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.unknownSigner);
      trust.decision = PluginRecoveryArchiveSignerTrustDecision.revoked;
      expect((await verifier.verify(signed)).disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.revokedSigner);
      trust.decision = PluginRecoveryArchiveSignerTrustDecision.disallowedAlgorithm;
      expect((await verifier.verify(signed)).disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.disallowedAlgorithm);

      trust.decision = PluginRecoveryArchiveSignerTrustDecision.trusted;
      final modified = PluginRecoveryArchiveSignedPackage(
        archivePackage: signed.archivePackage,
        signature: PluginRecoveryArchivePackageSignature(
          version: signed.signature.version,
          algorithm: signed.signature.algorithm,
          keyId: signed.signature.keyId,
          value: 'forged',
        ),
      );
      expect((await verifier.verify(modified)).disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.invalidSignature);
    });

    test('fails closed for unsupported signature versions', () async {
      final digest = _Digest();
      final package = await _package(digest);
      final verifier = PluginRecoveryArchivePackageAuthenticityVerifier(
        signatureVerifier: _SignatureVerifier(),
        trustPolicy: _TrustPolicy(),
      );
      final futureVersion = PluginRecoveryArchiveSignedPackage(
        archivePackage: package,
        signature: PluginRecoveryArchivePackageSignature(
          version: 2,
          algorithm: 'test-signature',
          keyId: 'publisher-key-1',
          value: 'signature',
        ),
      );
      expect((await verifier.verify(futureVersion)).disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.unsupportedSignatureVersion);
    });

    test('rechecks trust before import and does not write after revocation', () async {
      final digest = _Digest();
      final package = await _package(digest);
      final signed = await PluginRecoveryArchivePackageSigningService(
        signer: _Signer(),
      ).sign(
        archivePackage: package,
        algorithm: 'test-signature',
        keyId: 'publisher-key-1',
      );
      final trust = _TrustPolicy();
      final destination = _Archive();
      final importer = PluginRecoveryArchiveAuthenticatedPackageImporter(
        authenticityVerifier: PluginRecoveryArchivePackageAuthenticityVerifier(
          signatureVerifier: _SignatureVerifier(),
          trustPolicy: trust,
        ),
        packageImporter: PluginRecoveryArchivePackageImporter(
          destinationArchive: destination,
          digestProvider: digest,
        ),
      );
      final plan = await importer.inspect(signed);
      trust.decision = PluginRecoveryArchiveSignerTrustDecision.revoked;
      final report = await importer.importPackage(plan);
      expect(report.authenticity.disposition,
          PluginRecoveryArchivePackageAuthenticityDisposition.revokedSigner);
      expect(report.importReport, isNull);
      expect(destination.records, isEmpty);
    });
  });
}

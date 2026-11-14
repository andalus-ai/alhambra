import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const _digest = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Package implements PluginPackage {
  @override
  final PluginPackageManifest manifest = const PluginPackageManifest(
    id: PluginId('org.example.editor'),
    name: 'Example Editor',
    version: SemanticVersion(1, 2, 3),
    hostApi: HostApiConstraint(min: SemanticVersion(1, 0, 0)),
  );
  @override
  final PluginPackageMetadata metadata = const PluginPackageMetadata(
    packageId: 'org.example.editor',
    version: SemanticVersion(1, 2, 3),
    contentHash: _digest,
    formatVersion: 1,
  );
  @override
  final PluginPublisher? publisher = const PluginPublisher(
    id: 'publisher.example',
    name: 'Example Publisher',
  );
  @override
  final PluginPackageSignature? signature;

  _Package({this.signature});

  @override
  Stream<List<int>> readPayload(String path) async* {
    yield [1, 2, 3];
  }
}

class _Integrity implements PluginPayloadIntegrityVerifier {
  final String value;
  const _Integrity([this.value = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa']);

  @override
  Future<PluginPayloadDigest> digest(PluginPackage package) async =>
      PluginPayloadDigest(algorithm: 'sha256', value: value);
}

class _SignatureVerifier implements PluginCryptographicSignatureVerifier {
  final bool valid;
  List<int>? receivedMessage;
  _SignatureVerifier({this.valid = true});

  @override
  Future<bool> verify({
    required String algorithm,
    required String publicKey,
    required String signature,
    required List<int> message,
  }) async {
    receivedMessage = message;
    return valid;
  }
}

void main() {
  group('DefaultPluginPackageVerifier security boundary', () {
    test('requires an integrity provider even for policy-allowed unsigned packages', () async {
      final result = await DefaultPluginPackageVerifier().verify(_Package());
      expect(result, isA<PackageVerificationFailed>());
      expect((result as PackageVerificationFailed).issues.single.code,
          'INTEGRITY_VERIFIER_UNAVAILABLE');
    });

    test('rejects payload tampering before accepting unsigned package', () async {
      final result = await DefaultPluginPackageVerifier(
        integrityVerifier: const _Integrity('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
      ).verify(_Package());
      expect(result, isA<PackageVerificationFailed>());
      expect((result as PackageVerificationFailed).issues.single.code,
          'CONTENT_HASH_MISMATCH');
    });

    test('accepts unsigned only as unsigned after matching payload digest', () async {
      final result = await DefaultPluginPackageVerifier(
        integrityVerifier: const _Integrity(),
      ).verify(_Package());
      expect(result, const isA<PackageVerified>());
      expect((result as PackageVerified).trust, PluginTrustLevel.unsigned);
    });

    test('rejects signed package when cryptographic verifier is missing', () async {
      final trust = DefaultPluginTrustStore()
        ..addTrustedKey(const TrustedKey(
          keyId: 'key-1',
          algorithm: 'ed25519',
          publicKey: 'public-key',
        ));
      final result = await DefaultPluginPackageVerifier(
        trustStore: trust,
        integrityVerifier: const _Integrity(),
      ).verify(_Package(signature: const PluginPackageSignature(
        algorithm: 'ed25519',
        keyId: 'key-1',
        signature: 'signature',
      )));
      expect(result, isA<PackageVerificationFailed>());
      expect((result as PackageVerificationFailed).issues.single.code,
          'SIGNATURE_VERIFIER_UNAVAILABLE');
    });

    test('rejects revoked signing keys', () async {
      final trust = DefaultPluginTrustStore()
        ..addTrustedKey(TrustedKey(
          keyId: 'key-1',
          algorithm: 'ed25519',
          publicKey: 'public-key',
          revokedAt: DateTime.utc(2026, 1, 1),
        ));
      final result = await DefaultPluginPackageVerifier(
        trustStore: trust,
        integrityVerifier: const _Integrity(),
        signatureVerifier: _SignatureVerifier(),
      ).verify(_Package(signature: const PluginPackageSignature(
        algorithm: 'ed25519',
        keyId: 'key-1',
        signature: 'signature',
      )));
      expect(result, isA<PackageVerificationFailed>());
      expect((result as PackageVerificationFailed).issues.single.code,
          'REVOKED_SIGNING_KEY');
    });

    test('checks signature and promotes trust only for trusted publisher', () async {
      final trust = DefaultPluginTrustStore()
        ..addTrustedKey(const TrustedKey(
          keyId: 'key-1',
          algorithm: 'ed25519',
          publicKey: 'public-key',
          publisherId: 'publisher.example',
        ))
        ..addTrustedPublisher('publisher.example');
      final signatureVerifier = _SignatureVerifier();
      final result = await DefaultPluginPackageVerifier(
        trustStore: trust,
        integrityVerifier: const _Integrity(),
        signatureVerifier: signatureVerifier,
      ).verify(_Package(signature: const PluginPackageSignature(
        algorithm: 'ed25519',
        keyId: 'key-1',
        signature: 'signature',
      )));
      expect(result, isA<PackageVerified>());
      expect((result as PackageVerified).trust, PluginTrustLevel.trusted);
      expect(signatureVerifier.receivedMessage, isNotNull);
      expect(String.fromCharCodes(signatureVerifier.receivedMessage!),
          contains('content-hash=$_digest'));
    });

    test('rejects invalid signatures and key/publisher mismatch', () async {
      final trust = DefaultPluginTrustStore()
        ..addTrustedKey(const TrustedKey(
          keyId: 'key-1',
          algorithm: 'ed25519',
          publicKey: 'public-key',
          publisherId: 'other.publisher',
        ));
      final package = _Package(signature: const PluginPackageSignature(
        algorithm: 'ed25519',
        keyId: 'key-1',
        signature: 'signature',
      ));
      final mismatch = await DefaultPluginPackageVerifier(
        trustStore: trust,
        integrityVerifier: const _Integrity(),
        signatureVerifier: const _SignatureVerifier(),
      ).verify(package);
      expect((mismatch as PackageVerificationFailed).issues.single.code,
          'SIGNING_KEY_PUBLISHER_MISMATCH');

      final invalid = await DefaultPluginPackageVerifier(
        trustStore: DefaultPluginTrustStore()
          ..addTrustedKey(const TrustedKey(
            keyId: 'key-1',
            algorithm: 'ed25519',
            publicKey: 'public-key',
          )),
        integrityVerifier: const _Integrity(),
        signatureVerifier: _SignatureVerifier(valid: false),
      ).verify(package);
      expect((invalid as PackageVerificationFailed).issues.single.code,
          'INVALID_SIGNATURE');
    });
  });
}

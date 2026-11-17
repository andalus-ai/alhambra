import 'dart:convert';

import 'plugin_lifecycle_recovery_archive_package.dart';

/// Versioned signature metadata. The private key never enters Alhambra.
final class PluginRecoveryArchivePackageSignature {
  static const int currentVersion = 1;

  final int version;
  final String algorithm;
  final String keyId;
  final String value;

  PluginRecoveryArchivePackageSignature({
    required this.version,
    required this.algorithm,
    required this.keyId,
    required this.value,
  }) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version');
    }
    if (algorithm.trim().isEmpty) {
      throw ArgumentError.value(algorithm, 'algorithm');
    }
    if (keyId.trim().isEmpty) throw ArgumentError.value(keyId, 'keyId');
    if (value.trim().isEmpty) throw ArgumentError.value(value, 'value');
  }
}

/// A portable package plus its detached authenticity attestation.
final class PluginRecoveryArchiveSignedPackage {
  final PluginRecoveryArchivePackage archivePackage;
  final PluginRecoveryArchivePackageSignature signature;

  const PluginRecoveryArchiveSignedPackage({
    required this.archivePackage,
    required this.signature,
  });
}

/// Host-owned signing boundary. Implementations should use protected keys or
/// a remote KMS/HSM; raw private key material is never passed to this API.
abstract interface class PluginRecoveryArchivePackageSigner {
  Future<String> sign({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
  });
}

/// Host-owned signature verification boundary.
abstract interface class PluginRecoveryArchivePackageSignatureVerifier {
  Future<bool> verify({
    required String algorithm,
    required String keyId,
    required String canonicalPayload,
    required String signature,
  });
}

enum PluginRecoveryArchiveSignerTrustDecision {
  trusted,
  unknownSigner,
  revoked,
  disallowedAlgorithm,
}

/// Host policy evaluates signer identity, producer binding, key status,
/// validity windows, and algorithm allow-lists. No trust store is embedded.
final class PluginRecoveryArchiveSignerTrustAssessment {
  final PluginRecoveryArchiveSignerTrustDecision decision;
  final String? principalId;
  final String? reasonCode;

  const PluginRecoveryArchiveSignerTrustAssessment({
    required this.decision,
    this.principalId,
    this.reasonCode,
  });
}

abstract interface class PluginRecoveryArchivePackageTrustPolicy {
  Future<PluginRecoveryArchiveSignerTrustAssessment> assess({
    required String producer,
    required String keyId,
    required String algorithm,
    required DateTime packageCreatedAt,
  });
}

enum PluginRecoveryArchivePackageAuthenticityDisposition {
  valid,
  unsupportedSignatureVersion,
  unknownSigner,
  revokedSigner,
  disallowedAlgorithm,
  invalidSignature,
}

final class PluginRecoveryArchivePackageAuthenticityReport {
  final String packageId;
  final PluginRecoveryArchivePackageAuthenticityDisposition disposition;
  final String keyId;
  final String algorithm;
  final String? principalId;
  final String? reasonCode;

  const PluginRecoveryArchivePackageAuthenticityReport({
    required this.packageId,
    required this.disposition,
    required this.keyId,
    required this.algorithm,
    required this.principalId,
    required this.reasonCode,
  });

  bool get isValid =>
      disposition == PluginRecoveryArchivePackageAuthenticityDisposition.valid;
}

/// Signs the exact deterministic package encoding, including its manifest,
/// records, and package digest.
final class PluginRecoveryArchivePackageSigningService {
  final PluginRecoveryArchivePackageSigner signer;
  final PluginRecoveryArchivePackageCodec codec;

  const PluginRecoveryArchivePackageSigningService({
    required this.signer,
    this.codec = const PluginRecoveryArchivePackageCodec(),
  });

  Future<PluginRecoveryArchiveSignedPackage> sign({
    required PluginRecoveryArchivePackage archivePackage,
    required String algorithm,
    required String keyId,
  }) async {
    if (algorithm.trim().isEmpty) throw ArgumentError.value(algorithm, 'algorithm');
    if (keyId.trim().isEmpty) throw ArgumentError.value(keyId, 'keyId');
    final signature = await signer.sign(
      algorithm: algorithm,
      keyId: keyId,
      canonicalPayload: _signingPayload(
        codec: codec,
        archivePackage: archivePackage,
        algorithm: algorithm,
        keyId: keyId,
      ),
    );
    return PluginRecoveryArchiveSignedPackage(
      archivePackage: archivePackage,
      signature: PluginRecoveryArchivePackageSignature(
        version: PluginRecoveryArchivePackageSignature.currentVersion,
        algorithm: algorithm,
        keyId: keyId,
        value: signature,
      ),
    );
  }
}

/// Verifies trust policy and cryptographic signature independently of import.
final class PluginRecoveryArchivePackageAuthenticityVerifier {
  final PluginRecoveryArchivePackageSignatureVerifier signatureVerifier;
  final PluginRecoveryArchivePackageTrustPolicy trustPolicy;
  final PluginRecoveryArchivePackageCodec codec;

  const PluginRecoveryArchivePackageAuthenticityVerifier({
    required this.signatureVerifier,
    required this.trustPolicy,
    this.codec = const PluginRecoveryArchivePackageCodec(),
  });

  Future<PluginRecoveryArchivePackageAuthenticityReport> verify(
    PluginRecoveryArchiveSignedPackage signedPackage,
  ) async {
    final package = signedPackage.archivePackage;
    final signature = signedPackage.signature;
    if (signature.version != PluginRecoveryArchivePackageSignature.currentVersion) {
      return _report(
        signedPackage,
        PluginRecoveryArchivePackageAuthenticityDisposition.unsupportedSignatureVersion,
      );
    }
    final trust = await trustPolicy.assess(
      producer: package.manifest.producer,
      keyId: signature.keyId,
      algorithm: signature.algorithm,
      packageCreatedAt: package.manifest.createdAt,
    );
    final trustDisposition = switch (trust.decision) {
      PluginRecoveryArchiveSignerTrustDecision.trusted => null,
      PluginRecoveryArchiveSignerTrustDecision.unknownSigner =>
        PluginRecoveryArchivePackageAuthenticityDisposition.unknownSigner,
      PluginRecoveryArchiveSignerTrustDecision.revoked =>
        PluginRecoveryArchivePackageAuthenticityDisposition.revokedSigner,
      PluginRecoveryArchiveSignerTrustDecision.disallowedAlgorithm =>
        PluginRecoveryArchivePackageAuthenticityDisposition.disallowedAlgorithm,
    };
    if (trustDisposition != null) {
      return _report(
        signedPackage,
        trustDisposition,
        principalId: trust.principalId,
        reasonCode: trust.reasonCode,
      );
    }
    final valid = await signatureVerifier.verify(
      algorithm: signature.algorithm,
      keyId: signature.keyId,
      canonicalPayload: _signingPayload(
        codec: codec,
        archivePackage: package,
        algorithm: signature.algorithm,
        keyId: signature.keyId,
      ),
      signature: signature.value,
    );
    return _report(
      signedPackage,
      valid
          ? PluginRecoveryArchivePackageAuthenticityDisposition.valid
          : PluginRecoveryArchivePackageAuthenticityDisposition.invalidSignature,
      principalId: trust.principalId,
      reasonCode: valid ? trust.reasonCode : 'signature_mismatch',
    );
  }

  PluginRecoveryArchivePackageAuthenticityReport _report(
    PluginRecoveryArchiveSignedPackage signedPackage,
    PluginRecoveryArchivePackageAuthenticityDisposition disposition, {
    String? principalId,
    String? reasonCode,
  }) => PluginRecoveryArchivePackageAuthenticityReport(
    packageId: signedPackage.archivePackage.manifest.packageId,
    disposition: disposition,
    keyId: signedPackage.signature.keyId,
    algorithm: signedPackage.signature.algorithm,
    principalId: principalId,
    reasonCode: reasonCode,
  );
}

/// JSON transport for the signed package envelope. The detached signature
/// covers a domain-separated payload containing the package and signature metadata.
final class PluginRecoveryArchiveSignedPackageCodec {
  final PluginRecoveryArchivePackageCodec packageCodec;

  const PluginRecoveryArchiveSignedPackageCodec({
    this.packageCodec = const PluginRecoveryArchivePackageCodec(),
  });

  String encode(PluginRecoveryArchiveSignedPackage signedPackage) => jsonEncode({
    'envelopeVersion': 1,
    'package': jsonDecode(packageCodec.encode(signedPackage.archivePackage)),
    'signature': {
      'version': signedPackage.signature.version,
      'algorithm': signedPackage.signature.algorithm,
      'keyId': signedPackage.signature.keyId,
      'value': signedPackage.signature.value,
    },
  });

  PluginRecoveryArchiveSignedPackage decode(String source) {
    final root = _map(jsonDecode(source), 'signedPackage');
    if (root['envelopeVersion'] != 1) {
      throw const FormatException('Unsupported signed package envelope version.');
    }
    final signature = _map(root['signature'], 'signature');
    return PluginRecoveryArchiveSignedPackage(
      archivePackage: packageCodec.decode(jsonEncode(root['package'])),
      signature: PluginRecoveryArchivePackageSignature(
        version: _int(signature['version'], 'signature.version'),
        algorithm: _string(signature['algorithm'], 'signature.algorithm'),
        keyId: _string(signature['keyId'], 'signature.keyId'),
        value: _string(signature['value'], 'signature.value'),
      ),
    );
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object.');
    return value.map((key, value) {
      if (key is! String) throw FormatException('$field keys must be strings.');
      return MapEntry(key, value);
    });
  }

  static int _int(Object? value, String field) {
    if (value is! int) throw FormatException('$field must be an integer.');
    return value;
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string.');
    }
    return value;
  }
}

final class PluginRecoveryArchiveAuthenticatedImportPlan {
  final PluginRecoveryArchiveSignedPackage signedPackage;
  final PluginRecoveryArchivePackageAuthenticityReport authenticity;
  final PluginRecoveryArchivePackageImportPlan? packagePlan;

  const PluginRecoveryArchiveAuthenticatedImportPlan({
    required this.signedPackage,
    required this.authenticity,
    required this.packagePlan,
  });

  bool get canImport => authenticity.isValid && (packagePlan?.canImport ?? false);
}

final class PluginRecoveryArchiveAuthenticatedImportReport {
  final PluginRecoveryArchivePackageAuthenticityReport authenticity;
  final PluginRecoveryArchivePackageImportReport? importReport;

  const PluginRecoveryArchiveAuthenticatedImportReport({
    required this.authenticity,
    required this.importReport,
  });
}

/// Import facade for hosts that require authenticated packages. The signature
/// and trust policy are checked at preview and again immediately before import.
final class PluginRecoveryArchiveAuthenticatedPackageImporter {
  final PluginRecoveryArchivePackageAuthenticityVerifier authenticityVerifier;
  final PluginRecoveryArchivePackageImporter packageImporter;

  const PluginRecoveryArchiveAuthenticatedPackageImporter({
    required this.authenticityVerifier,
    required this.packageImporter,
  });

  Future<PluginRecoveryArchiveAuthenticatedImportPlan> inspect(
    PluginRecoveryArchiveSignedPackage signedPackage,
  ) async {
    final authenticity = await authenticityVerifier.verify(signedPackage);
    if (!authenticity.isValid) {
      return PluginRecoveryArchiveAuthenticatedImportPlan(
        signedPackage: signedPackage,
        authenticity: authenticity,
        packagePlan: null,
      );
    }
    final packagePlan = await packageImporter.inspect(signedPackage.archivePackage);
    return PluginRecoveryArchiveAuthenticatedImportPlan(
      signedPackage: signedPackage,
      authenticity: authenticity,
      packagePlan: packagePlan,
    );
  }

  Future<PluginRecoveryArchiveAuthenticatedImportReport> importPackage(
    PluginRecoveryArchiveAuthenticatedImportPlan plan,
  ) async {
    final authenticity = await authenticityVerifier.verify(plan.signedPackage);
    if (!authenticity.isValid) {
      return PluginRecoveryArchiveAuthenticatedImportReport(
        authenticity: authenticity,
        importReport: null,
      );
    }
    final packagePlan = plan.packagePlan;
    if (packagePlan == null ||
        !plan.canImport ||
        const PluginRecoveryArchivePackageCodec().encode(
              packagePlan.archivePackage,
            ) !=
            const PluginRecoveryArchivePackageCodec().encode(
              plan.signedPackage.archivePackage,
            )) {
      throw StateError('Authenticated archive import is blocked by its preview plan.');
    }
    final importReport = await packageImporter.importPackage(packagePlan);
    return PluginRecoveryArchiveAuthenticatedImportReport(
      authenticity: authenticity,
      importReport: importReport,
    );
  }
}


String _signingPayload({
  required PluginRecoveryArchivePackageCodec codec,
  required PluginRecoveryArchivePackage archivePackage,
  required String algorithm,
  required String keyId,
}) => jsonEncode({
  'domain': 'alhambra.recovery-archive-package.signature.v1',
  'algorithm': algorithm,
  'keyId': keyId,
  'package': jsonDecode(codec.encode(archivePackage)),
});

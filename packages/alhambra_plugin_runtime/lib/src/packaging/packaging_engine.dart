import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// In-memory trust store for public keys and publisher IDs.
///
/// Production hosts should supply a durable, administratively managed store.
class DefaultPluginTrustStore implements PluginTrustStore {
  final Map<String, TrustedKey> _keys = {};
  final Set<String> _trustedPublishers = {};

  @override
  void addTrustedKey(TrustedKey key) => _keys[key.keyId] = key;

  @override
  void addTrustedPublisher(String publisherId) =>
      _trustedPublishers.add(publisherId);

  @override
  Future<TrustedKey?> findKey(String keyId) async => _keys[keyId];

  @override
  Future<bool> isPublisherTrusted(String publisherId) async =>
      _trustedPublishers.contains(publisherId);
}

/// Default configurable plugin security policy.
class DefaultPluginSecurityPolicy implements PluginSecurityPolicy {
  final bool allowsUnsigned;
  final bool requiresSignature;
  final Set<String> blockedPublishers;

  const DefaultPluginSecurityPolicy({
    this.allowsUnsigned = true,
    this.requiresSignature = false,
    this.blockedPublishers = const {},
  });

  @override
  bool allowPublisher(PluginPublisher publisher) =>
      !blockedPublishers.contains(publisher.id);

  @override
  bool allowUnsigned(PluginPackage package) => allowsUnsigned;

  @override
  bool requireSignature(PluginPackage package) => requiresSignature;
}

/// Verifies package payload integrity and publisher signatures through
/// injected cryptographic adapters. This class intentionally implements no
/// cryptographic primitive itself.
class DefaultPluginPackageVerifier implements PluginPackageVerifier {
  final PluginTrustStore trustStore;
  final PluginSecurityPolicy securityPolicy;
  final PluginPayloadIntegrityVerifier? integrityVerifier;
  final PluginCryptographicSignatureVerifier? signatureVerifier;

  static const supportedFormatVersion = 1;
  static final RegExp _sha256Pattern = RegExp(r'^sha256:[0-9a-f]{64}$');

  DefaultPluginPackageVerifier({
    PluginTrustStore? trustStore,
    PluginSecurityPolicy? securityPolicy,
    this.integrityVerifier,
    this.signatureVerifier,
  }) : trustStore = trustStore ?? DefaultPluginTrustStore(),
       securityPolicy = securityPolicy ?? const DefaultPluginSecurityPolicy();

  @override
  Future<PackageVerificationResult> verify(PluginPackage package) async {
    final issues = <VerificationIssue>[];
    final metadata = package.metadata;
    final manifest = package.manifest;
    final publisher = package.publisher;
    final signature = package.signature;

    if (metadata.formatVersion < 1 ||
        metadata.formatVersion > supportedFormatVersion) {
      issues.add(VerificationIssue(
        code: 'UNSUPPORTED_FORMAT',
        message: 'Package format version ${metadata.formatVersion} is not supported (supported: 1).',
      ));
    }
    if (metadata.packageId != manifest.id.value) {
      issues.add(const VerificationIssue(
        code: 'PACKAGE_ID_MISMATCH',
        message: 'Package metadata ID does not match manifest ID.',
      ));
    }
    if (metadata.version != manifest.version) {
      issues.add(const VerificationIssue(
        code: 'PACKAGE_VERSION_MISMATCH',
        message: 'Package metadata version does not match manifest version.',
      ));
    }
    if (!_sha256Pattern.hasMatch(metadata.contentHash.toLowerCase())) {
      issues.add(const VerificationIssue(
        code: 'INVALID_CONTENT_HASH',
        message: 'Content hash must use sha256:<64 hexadecimal characters> encoding.',
      ));
    }
    if (publisher != null && !securityPolicy.allowPublisher(publisher)) {
      issues.add(VerificationIssue(
        code: 'BLOCKED_PUBLISHER',
        message: 'Publisher ${publisher.id} is blocked by policy.',
      ));
    }
    if (signature == null &&
        (securityPolicy.requireSignature(package) ||
            !securityPolicy.allowUnsigned(package))) {
      issues.add(const VerificationIssue(
        code: 'UNSIGNED_DENIED',
        message: 'Package is unsigned but policy requires a valid cryptographic signature.',
      ));
    }
    if (issues.isNotEmpty) return PackageVerificationFailed(issues);

    final integrity = integrityVerifier;
    if (integrity == null) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'INTEGRITY_VERIFIER_UNAVAILABLE',
          message: 'A payload integrity verifier is required for every package.',
        ),
      ]);
    }

    final PluginPayloadDigest digest;
    try {
      digest = await integrity.digest(package);
    } catch (error) {
      return PackageVerificationFailed([
        VerificationIssue(
          code: 'INTEGRITY_CHECK_FAILED',
          message: 'Payload digest computation failed: $error',
        ),
      ]);
    }
    if (digest.algorithm.toLowerCase() != 'sha256' ||
        digest.encoded != metadata.contentHash.toLowerCase()) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'CONTENT_HASH_MISMATCH',
          message: 'Computed SHA-256 payload digest does not match package metadata.',
        ),
      ]);
    }

    if (signature == null) {
      return const PackageVerified(PluginTrustLevel.unsigned);
    }

    final key = await trustStore.findKey(signature.keyId);
    if (key == null) {
      return PackageVerificationFailed([
        VerificationIssue(
          code: 'UNKNOWN_SIGNING_KEY',
          message: 'Signing key ${signature.keyId} was not found in the trust store.',
        ),
      ]);
    }
    if (key.algorithm.toLowerCase() != signature.algorithm.toLowerCase()) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'SIGNATURE_ALGORITHM_MISMATCH',
          message: 'Signature algorithm does not match the trusted key algorithm.',
        ),
      ]);
    }
    if (key.isRevoked) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'REVOKED_SIGNING_KEY',
          message: 'Signing key has been revoked.',
        ),
      ]);
    }
    final now = DateTime.now().toUtc();
    if (key.notBefore != null && now.isBefore(key.notBefore!)) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'SIGNING_KEY_NOT_YET_VALID',
          message: 'Signing key is not yet valid.',
        ),
      ]);
    }
    if (key.notAfter != null && !now.isBefore(key.notAfter!)) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'SIGNING_KEY_EXPIRED',
          message: 'Signing key has expired.',
        ),
      ]);
    }
    if (publisher != null && key.publisherId != publisher.id) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'SIGNING_KEY_PUBLISHER_MISMATCH',
          message: 'Signing key is not bound to the package publisher.',
        ),
      ]);
    }

    final crypto = signatureVerifier;
    if (crypto == null) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'SIGNATURE_VERIFIER_UNAVAILABLE',
          message: 'A cryptographic signature verifier is required for signed packages.',
        ),
      ]);
    }
    final bool valid;
    try {
      valid = await crypto.verify(
        algorithm: signature.algorithm,
        publicKey: key.publicKey,
        signature: signature.signature,
        message: canonicalPluginPackageSigningStatement(package),
      );
    } catch (error) {
      return PackageVerificationFailed([
        VerificationIssue(
          code: 'SIGNATURE_CHECK_FAILED',
          message: 'Cryptographic signature verification failed: $error',
        ),
      ]);
    }
    if (!valid) {
      return PackageVerificationFailed(const [
        VerificationIssue(
          code: 'INVALID_SIGNATURE',
          message: 'Package signature verification failed.',
        ),
      ]);
    }

    final trustedPublisher = publisher != null &&
        await trustStore.isPublisherTrusted(publisher.id);
    return PackageVerified(
      trustedPublisher ? PluginTrustLevel.trusted : PluginTrustLevel.verified,
    );
  }
}

/// In-memory installed-plugin store; intended as a reference implementation.
class InMemoryInstalledPluginStore implements InstalledPluginStore {
  final Map<String, InstalledPluginRecord> _installed = {};

  @override
  Future<List<InstalledPluginRecord>> all() async =>
      _installed.values.toList(growable: false);

  @override
  Future<InstalledPluginRecord?> find(String pluginId) async =>
      _installed[pluginId];

  @override
  Future<void> remove(String pluginId) async {
    _installed.remove(pluginId);
  }

  @override
  Future<void> save(InstalledPluginRecord plugin) async {
    _installed[plugin.id] = plugin;
  }
}

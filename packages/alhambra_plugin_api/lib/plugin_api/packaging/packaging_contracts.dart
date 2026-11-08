import '../manifest/manifest_models.dart';

/// Metadata describing an archive/bundle package.
final class PluginPackageMetadata {
  final String packageId;
  final SemanticVersion version;
  final String contentHash;
  final int formatVersion;

  const PluginPackageMetadata({
    required this.packageId,
    required this.version,
    required this.contentHash,
    required this.formatVersion,
  });
}

/// Publisher identity attached to package verification.
final class PluginPublisher {
  final String id;
  final String name;
  final String? website;

  const PluginPublisher({
    required this.id,
    required this.name,
    this.website,
  });
}

/// Cryptographic signature associated with a package payload.
final class PluginPackageSignature {
  final String algorithm;
  final String keyId;
  final String signature;

  const PluginPackageSignature({
    required this.algorithm,
    required this.keyId,
    required this.signature,
  });
}

/// Transport-neutral abstract plugin package.
abstract interface class PluginPackage {
  PluginPackageManifest get manifest;
  PluginPackageMetadata get metadata;
  PluginPublisher? get publisher;
  PluginPackageSignature? get signature;
  Stream<List<int>> readPayload(String path);
}

/// Trust levels for verified packages.
enum PluginTrustLevel {
  trusted,
  verified,
  unsigned,
  blocked,
}

/// Issue detected during verification.
final class VerificationIssue {
  final String code;
  final String message;
  final bool isFatal;

  const VerificationIssue({
    required this.code,
    required this.message,
    this.isFatal = true,
  });
}

/// Outcome of package verification.
sealed class PackageVerificationResult {
  const PackageVerificationResult();
}

final class PackageVerified extends PackageVerificationResult {
  final PluginTrustLevel trust;
  const PackageVerified(this.trust);
}

final class PackageVerificationFailed extends PackageVerificationResult {
  final List<VerificationIssue> issues;
  const PackageVerificationFailed(this.issues);
}

/// Public key representation in trust store.
final class TrustedKey {
  final String keyId;
  final String algorithm;
  final String publicKey;

  const TrustedKey({
    required this.keyId,
    required this.algorithm,
    required this.publicKey,
  });
}

/// Trust store for signature and publisher verification.
abstract interface class PluginTrustStore {
  Future<TrustedKey?> findKey(String keyId);
  Future<bool> isPublisherTrusted(String publisherId);
  void addTrustedKey(TrustedKey key);
  void addTrustedPublisher(String publisherId);
}

/// Security policy controlling verification requirements.
abstract interface class PluginSecurityPolicy {
  bool allowUnsigned(PluginPackage package);
  bool allowPublisher(PluginPublisher publisher);
  bool requireSignature(PluginPackage package);
}

/// Dedicated verifier service checking integrity, hashes, signatures, and publisher.
abstract interface class PluginPackageVerifier {
  Future<PackageVerificationResult> verify(PluginPackage package);
}

/// Result of package installation.
sealed class InstallationResult {
  const InstallationResult();
}

final class PluginInstalled extends InstallationResult {
  final String pluginId;
  final SemanticVersion version;
  final String installPath;

  const PluginInstalled({
    required this.pluginId,
    required this.version,
    required this.installPath,
  });
}

final class PluginInstallationFailed extends InstallationResult {
  final String reason;
  const PluginInstallationFailed(this.reason);
}

/// Installed plugin record in metadata storage.
final class InstalledPluginRecord {
  final String id;
  final SemanticVersion version;
  final String contentHash;
  final PluginPublisher? publisher;
  final DateTime installedAt;
  final String installPath;

  const InstalledPluginRecord({
    required this.id,
    required this.version,
    required this.contentHash,
    required this.installedAt,
    required this.installPath,
    this.publisher,
  });
}

/// Store persisting installed plugin records.
abstract interface class InstalledPluginStore {
  Future<List<InstalledPluginRecord>> all();
  Future<InstalledPluginRecord?> find(String pluginId);
  Future<void> save(InstalledPluginRecord plugin);
  Future<void> remove(String pluginId);
}

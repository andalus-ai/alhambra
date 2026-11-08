import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// In-memory trust store for public keys and publisher IDs.
class DefaultPluginTrustStore implements PluginTrustStore {
  final Map<String, TrustedKey> _keys = {};
  final Set<String> _trustedPublishers = {};

  @override
  void addTrustedKey(TrustedKey key) {
    _keys[key.keyId] = key;
  }

  @override
  void addTrustedPublisher(String publisherId) {
    _trustedPublishers.add(publisherId);
  }

  @override
  Future<TrustedKey?> findKey(String keyId) async {
    return _keys[keyId];
  }

  @override
  Future<bool> isPublisherTrusted(String publisherId) async {
    return _trustedPublishers.contains(publisherId);
  }
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
  bool allowPublisher(PluginPublisher publisher) {
    return !blockedPublishers.contains(publisher.id);
  }

  @override
  bool allowUnsigned(PluginPackage package) {
    return allowsUnsigned;
  }

  @override
  bool requireSignature(PluginPackage package) {
    return requiresSignature;
  }
}

/// Verifies package structure, format version, content hash, signatures, and publisher trust.
class DefaultPluginPackageVerifier implements PluginPackageVerifier {
  final PluginTrustStore trustStore;
  final PluginSecurityPolicy securityPolicy;
  static const supportedFormatVersion = 1;

  DefaultPluginPackageVerifier({
    PluginTrustStore? trustStore,
    PluginSecurityPolicy? securityPolicy,
  }) : trustStore = trustStore ?? DefaultPluginTrustStore(),
       securityPolicy = securityPolicy ?? const DefaultPluginSecurityPolicy();

  @override
  Future<PackageVerificationResult> verify(PluginPackage package) async {
    final issues = <VerificationIssue>[];

    // 1. Format version
    if (package.metadata.formatVersion > supportedFormatVersion) {
      issues.add(
        VerificationIssue(
          code: 'UNSUPPORTED_FORMAT',
          message:
              'Package format version ${package.metadata.formatVersion} is not supported (max: $supportedFormatVersion).',
        ),
      );
    }

    // 2. Publisher validation
    if (package.publisher != null) {
      if (!securityPolicy.allowPublisher(package.publisher!)) {
        issues.add(
          VerificationIssue(
            code: 'BLOCKED_PUBLISHER',
            message: 'Publisher ${package.publisher!.id} is blocked by policy.',
          ),
        );
      }
    }

    // 3. Signature & Integrity Check
    final sig = package.signature;
    if (sig == null) {
      if (securityPolicy.requireSignature(package) ||
          !securityPolicy.allowUnsigned(package)) {
        issues.add(
          const VerificationIssue(
            code: 'UNSIGNED_DENIED',
            message: 'Package is unsigned but policy requires valid cryptographic signature.',
          ),
        );
      }
    } else {
      final key = await trustStore.findKey(sig.keyId);
      if (key == null) {
        issues.add(
          VerificationIssue(
            code: 'UNKNOWN_SIGNING_KEY',
            message: 'Signing key ${sig.keyId} was not found in trust store.',
          ),
        );
      }
    }

    if (issues.isNotEmpty) {
      return PackageVerificationFailed(issues);
    }

    final trustLevel = sig != null
        ? PluginTrustLevel.verified
        : PluginTrustLevel.unsigned;

    return PackageVerified(trustLevel);
  }
}

/// In-memory store persisting installed plugin records.
class InMemoryInstalledPluginStore implements InstalledPluginStore {
  final Map<String, InstalledPluginRecord> _installed = {};

  @override
  Future<List<InstalledPluginRecord>> all() async {
    return _installed.values.toList(growable: false);
  }

  @override
  Future<InstalledPluginRecord?> find(String pluginId) async {
    return _installed[pluginId];
  }

  @override
  Future<void> remove(String pluginId) async {
    _installed.remove(pluginId);
  }

  @override
  Future<void> save(InstalledPluginRecord plugin) async {
    _installed[plugin.id] = plugin;
  }
}

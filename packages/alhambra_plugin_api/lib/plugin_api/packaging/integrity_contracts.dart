import 'dart:convert';

import 'packaging_contracts.dart';

/// Computes a digest over canonical package payload bytes. The adapter owns
/// archive traversal and canonicalization; packagers must use the same form.
abstract interface class PluginPayloadIntegrityVerifier {
  Future<PluginPayloadDigest> digest(PluginPackage package);
}

final class PluginPayloadDigest {
  final String algorithm;
  final String value;

  const PluginPayloadDigest({required this.algorithm, required this.value});

  String get encoded => '${algorithm.toLowerCase()}:${value.toLowerCase()}';
}

/// Adapter to a vetted cryptographic implementation. Alhambra does not
/// implement cryptographic primitives or silently select an algorithm.
abstract interface class PluginCryptographicSignatureVerifier {
  Future<bool> verify({
    required String algorithm,
    required String publicKey,
    required String signature,
    required List<int> message,
  });
}

/// Versioned canonical statement bound by a publisher's detached signature.
List<int> canonicalPluginPackageSigningStatement(PluginPackage package) {
  final metadata = package.metadata;
  final manifest = package.manifest;
  final publisherId = package.publisher?.id ?? '';
  final statement = [
    'alhambra-plugin-package-v1',
    'plugin-id=${manifest.id.value}',
    'plugin-version=${manifest.version}',
    'package-id=${metadata.packageId}',
    'package-version=${metadata.version}',
    'format-version=${metadata.formatVersion}',
    'content-hash=${metadata.contentHash.toLowerCase()}',
    'publisher-id=$publisherId',
  ].join('\n');
  return utf8.encode(statement);
}

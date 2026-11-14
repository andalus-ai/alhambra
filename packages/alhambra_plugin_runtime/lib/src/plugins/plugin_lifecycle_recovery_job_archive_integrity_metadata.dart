/// Digest metadata attached to an archived recovery-job snapshot.
final class PluginLifecycleRecoveryJobArchiveIntegrity {
  final int formatVersion;
  final String algorithm;
  final String digest;

  PluginLifecycleRecoveryJobArchiveIntegrity({
    required this.formatVersion,
    required this.algorithm,
    required this.digest,
  }) {
    if (formatVersion < 1) throw ArgumentError.value(formatVersion, 'formatVersion');
    if (algorithm.trim().isEmpty) throw ArgumentError.value(algorithm, 'algorithm');
    if (digest.trim().isEmpty) throw ArgumentError.value(digest, 'digest');
  }
}

/// One failed plugin conformance check.
final class PluginConformanceIssue {
  const PluginConformanceIssue({required this.code, required this.message, this.path});
  final String code;
  final String message;
  final String? path;
  @override
  String toString() => path == null ? '$code: $message' : '$code ($path): $message';
}

/// Immutable result of a plugin conformance run.
final class PluginConformanceResult {
  PluginConformanceResult(Iterable<PluginConformanceIssue> issues)
      : issues = List<PluginConformanceIssue>.unmodifiable(issues);
  final List<PluginConformanceIssue> issues;
  bool get isConformant => issues.isEmpty;
  void throwIfNotConformant() {
    if (isConformant) return;
    throw StateError('Plugin is not conformant:\n' +
        issues.map((issue) => '- $issue').join('\n'));
  }
}

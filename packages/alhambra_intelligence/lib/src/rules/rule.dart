/// Input context evaluated by a [Rule].
final class RuleContext {
  final Map<String, Object?> inputs;

  const RuleContext([this.inputs = const {}]);

  T? get<T>(String key) => inputs[key] as T?;
}

/// Evaluation output of a [Rule].
final class RuleResult {
  final bool matched;
  final Map<String, Object?> outputs;
  final String? message;

  const RuleResult({
    required this.matched,
    this.outputs = const {},
    this.message,
  });

  @override
  String toString() => 'RuleResult(matched: $matched, outputs: $outputs)';
}

/// Contract for declarative domain validation or relationship rules.
abstract interface class Rule {
  String get id;

  RuleResult evaluate(RuleContext context);
}

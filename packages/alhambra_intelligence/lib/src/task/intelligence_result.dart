import 'package:alhambra_core/alhambra_core.dart';
import '../artifact/intelligence_artifact.dart';
import '../evidence/evidence.dart';

/// The final outcome of an executed [IntelligenceRequest].
final class IntelligenceResult {
  final AnalysisId requestId;
  final ExecutionId executionId;
  final bool success;
  final String? summary;
  final List<Evidence> evidence;
  final List<IntelligenceArtifact> artifacts;
  final Map<String, Object?> outputs;
  final List<String> warnings;
  final AlhambraError? error;

  const IntelligenceResult({
    required this.requestId,
    required this.executionId,
    required this.success,
    this.summary,
    this.evidence = const [],
    this.artifacts = const [],
    this.outputs = const {},
    this.warnings = const [],
    this.error,
  });

  @override
  String toString() =>
      'IntelligenceResult(request: $requestId, exec: $executionId, ok: $success, evidence: ${evidence.length}, artifacts: ${artifacts.length})';
}

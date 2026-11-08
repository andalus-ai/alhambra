import 'package:alhambra_core/alhambra_core.dart';
import 'intelligence_execution_status.dart';

/// Tracks a runtime execution of an [IntelligenceRequest] and its [IntelligencePlan].
final class IntelligenceExecution {
  final ExecutionId executionId;
  final AnalysisId requestId;
  final String? planId;
  final IntelligenceExecutionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? currentStepId;
  final String? failureReason;
  final Map<String, Object?> outputs;

  const IntelligenceExecution({
    required this.executionId,
    required this.requestId,
    this.planId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.currentStepId,
    this.failureReason,
    this.outputs = const {},
  });

  IntelligenceExecution copyWith({
    IntelligenceExecutionStatus? status,
    DateTime? completedAt,
    String? currentStepId,
    String? failureReason,
    Map<String, Object?>? outputs,
  }) {
    return IntelligenceExecution(
      executionId: executionId,
      requestId: requestId,
      planId: planId,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentStepId: currentStepId ?? this.currentStepId,
      failureReason: failureReason ?? this.failureReason,
      outputs: outputs ?? this.outputs,
    );
  }

  @override
  String toString() =>
      'IntelligenceExecution($executionId for $requestId: $status, step: $currentStepId)';
}

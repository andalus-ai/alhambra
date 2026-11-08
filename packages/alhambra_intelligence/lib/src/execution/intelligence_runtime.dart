import 'dart:async';
import 'package:alhambra_core/alhambra_core.dart';
import '../plan/intelligence_plan.dart';
import '../review/review_decision.dart';
import '../task/intelligence_request.dart';
import 'intelligence_execution.dart';
import 'intelligence_execution_event.dart';

/// Contract connecting Alhambra Intelligence with an execution engine (Local or Andalus).
abstract interface class IntelligenceRuntime {
  /// Starts a new execution of [plan] for [request].
  Future<IntelligenceExecution> start(
    IntelligenceRequest request,
    IntelligencePlan plan,
  );

  /// Resumes a paused execution (e.g. from `waitingForReview`).
  Future<IntelligenceExecution> resume(
    ExecutionId executionId,
    ReviewDecision decision,
  );

  /// Retrieves current execution state by [executionId].
  Future<IntelligenceExecution?> getExecution(ExecutionId executionId);

  /// Stream of real-time lifecycle and progress events for [executionId].
  Stream<IntelligenceExecutionEvent> events(ExecutionId executionId);
}

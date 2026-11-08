import 'dart:async';
import 'package:alhambra_core/alhambra_core.dart';
import '../plan/intelligence_plan.dart';
import '../plan/intelligence_step_handler.dart';
import '../review/review_decision.dart';
import '../review/review_request.dart';
import '../task/intelligence_request.dart';
import 'intelligence_execution.dart';
import 'intelligence_execution_event.dart';
import 'intelligence_execution_status.dart';
import 'intelligence_runtime.dart';

/// Lightweight in-memory [IntelligenceRuntime] for local testing and standalone workflows.
class LocalIntelligenceRuntime implements IntelligenceRuntime {
  final Map<String, IntelligenceStepHandler> _handlers = {};
  final Map<ExecutionId, IntelligenceExecution> _executions = {};
  final Map<ExecutionId, StreamController<IntelligenceExecutionEvent>> _controllers = {};
  final Map<ExecutionId, ({IntelligenceRequest request, IntelligencePlan plan, int nextStepIdx})>
      _pendingExecutions = {};

  LocalIntelligenceRuntime([List<IntelligenceStepHandler>? handlers]) {
    if (handlers != null) {
      for (final h in handlers) {
        for (final type in h.supportedTypes) {
          _handlers[type] = h;
        }
      }
    }
  }

  void registerHandler(IntelligenceStepHandler handler) {
    for (final type in handler.supportedTypes) {
      _handlers[type] = handler;
    }
  }

  StreamController<IntelligenceExecutionEvent> _ensureController(ExecutionId id) {
    return _controllers.putIfAbsent(
      id,
      () => StreamController<IntelligenceExecutionEvent>.broadcast(),
    );
  }

  void _emit(ExecutionId id, IntelligenceExecutionEvent event) {
    final ctrl = _controllers[id];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(event);
    }
  }

  @override
  Stream<IntelligenceExecutionEvent> events(ExecutionId executionId) {
    return _ensureController(executionId).stream;
  }

  @override
  Future<IntelligenceExecution?> getExecution(ExecutionId executionId) async {
    return _executions[executionId];
  }

  @override
  Future<IntelligenceExecution> start(
    IntelligenceRequest request,
    IntelligencePlan plan,
  ) async {
    final execId = ExecutionId('exec-${DateTime.now().microsecondsSinceEpoch}');
    _ensureController(execId);

    var execution = IntelligenceExecution(
      executionId: execId,
      requestId: request.requestId,
      planId: plan.planId,
      status: IntelligenceExecutionStatus.running,
      startedAt: DateTime.now(),
    );
    _executions[execId] = execution;
    _emit(execId, ExecutionStatusChanged(
      executionId: execId,
      timestamp: DateTime.now(),
      status: IntelligenceExecutionStatus.running,
    ));

    return _runSteps(execId, request, plan, startIndex: 0);
  }

  Future<IntelligenceExecution> _runSteps(
    ExecutionId execId,
    IntelligenceRequest request,
    IntelligencePlan plan, {
    required int startIndex,
    bool isResumed = false,
  }) async {
    final state = IntelligenceState();

    for (int i = startIndex; i < plan.steps.length; i++) {
      final step = plan.steps[i];

      // Check if step requires human review or constraints require it
      final stepApproved = i == startIndex && isResumed;
      if (!stepApproved &&
          request.constraints.requireHumanReview &&
          step.type == 'synthesize_findings') {
        _pendingExecutions[execId] = (
          request: request,
          plan: plan,
          nextStepIdx: i,
        );

        final paused = _executions[execId]!.copyWith(
          status: IntelligenceExecutionStatus.waitingForReview,
          currentStepId: step.id,
        );
        _executions[execId] = paused;

        _emit(execId, ExecutionStatusChanged(
          executionId: execId,
          timestamp: DateTime.now(),
          status: IntelligenceExecutionStatus.waitingForReview,
        ));
        _emit(execId, ReviewRequestedEvent(
          executionId: execId,
          timestamp: DateTime.now(),
          request: ReviewRequest(
            executionId: execId,
            subject: 'Review step ${step.id}',
            reason: 'Human review required before synthesis',
            stepId: step.id,
          ),
        ));

        return paused;
      }

      _emit(execId, StepStarted(
        executionId: execId,
        timestamp: DateTime.now(),
        stepId: step.id,
        stepType: step.type,
      ));

      final handler = _handlers[step.type];
      if (handler != null) {
        await handler.execute(step, state);
      }

      state.completedSteps.add(step.id);
      _emit(execId, StepCompleted(
        executionId: execId,
        timestamp: DateTime.now(),
        stepId: step.id,
      ));
    }

    final completed = _executions[execId]!.copyWith(
      status: IntelligenceExecutionStatus.completed,
      completedAt: DateTime.now(),
      outputs: state.variables,
    );
    _executions[execId] = completed;

    _emit(execId, ExecutionStatusChanged(
      executionId: execId,
      timestamp: DateTime.now(),
      status: IntelligenceExecutionStatus.completed,
    ));

    return completed;
  }

  @override
  Future<IntelligenceExecution> resume(
    ExecutionId executionId,
    ReviewDecision decision,
  ) async {
    final pending = _pendingExecutions.remove(executionId);
    if (pending == null) {
      throw StateError('No paused execution found for id: $executionId');
    }

    if (decision == ReviewDecision.reject) {
      final rejected = _executions[executionId]!.copyWith(
        status: IntelligenceExecutionStatus.failed,
        completedAt: DateTime.now(),
        failureReason: 'Rejected during human review',
      );
      _executions[executionId] = rejected;

      _emit(executionId, ExecutionStatusChanged(
        executionId: executionId,
        timestamp: DateTime.now(),
        status: IntelligenceExecutionStatus.failed,
      ));

      return rejected;
    }

    // If approved, resume running remaining steps
    final resumed = _executions[executionId]!.copyWith(
      status: IntelligenceExecutionStatus.running,
    );
    _executions[executionId] = resumed;

    _emit(executionId, ExecutionStatusChanged(
      executionId: executionId,
      timestamp: DateTime.now(),
      status: IntelligenceExecutionStatus.running,
    ));

    return _runSteps(
      executionId,
      pending.request,
      pending.plan,
      startIndex: pending.nextStepIdx,
      isResumed: true,
    );
  }
}

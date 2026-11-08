/// Alhambra Intelligence — intelligence contracts, planning, execution,
/// knowledge, memory, evidence, governance, and Andalus runtime bridge.
///
/// Pure Dart. No Flutter dependencies. No domain-specific types.
library;

// Agent
export 'src/agent/intelligence_agent.dart';

// Task & Request
export 'src/task/intelligence_objective.dart';
export 'src/task/intelligence_scope.dart';
export 'src/task/intelligence_constraints.dart';
export 'src/task/intelligence_context.dart';
export 'src/task/intelligence_request.dart';
export 'src/task/intelligence_result.dart';

// Plan
export 'src/plan/intelligence_step.dart';
export 'src/plan/intelligence_plan.dart';
export 'src/plan/intelligence_planner.dart';
export 'src/plan/intelligence_step_handler.dart';

// Execution
export 'src/execution/intelligence_execution_status.dart';
export 'src/execution/intelligence_execution.dart';
export 'src/execution/intelligence_execution_event.dart';
export 'src/execution/intelligence_runtime.dart';
export 'src/execution/local_intelligence_runtime.dart';

// Knowledge
export 'src/knowledge/knowledge_item.dart';
export 'src/knowledge/knowledge_query.dart';
export 'src/knowledge/knowledge_binding.dart';
export 'src/knowledge/knowledge_repository.dart';
export 'src/knowledge/knowledge_resolver.dart';

// Memory
export 'src/memory/memory_record.dart';
export 'src/memory/memory_query.dart';
export 'src/memory/memory_store.dart';
export 'src/memory/memory_retriever.dart';

// Evidence & Confidence
export 'src/evidence/confidence_factor.dart';
export 'src/evidence/confidence.dart';
export 'src/evidence/evidence_type.dart';
export 'src/evidence/evidence.dart';

// Policy
export 'src/policy/policy_violation.dart';
export 'src/policy/policy_decision.dart';
export 'src/policy/intelligence_policy.dart';

// Rules
export 'src/rules/rule.dart';

// Review (Human-in-the-loop)
export 'src/review/review_decision.dart';
export 'src/review/review_request.dart';
export 'src/review/human_review_service.dart';

// Artifacts & Epistemic Classification
export 'src/artifact/epistemic_class.dart';
export 'src/artifact/artifact_type.dart';
export 'src/artifact/artifact_metadata.dart';
export 'src/artifact/intelligence_artifact.dart';

// Provenance
export 'src/provenance/provenance_ref.dart';
export 'src/provenance/provenance_graph.dart';

import 'package:alhambra_core/alhambra_core.dart';
import 'package:alhambra_intelligence/alhambra_intelligence.dart';
import 'package:test/test.dart';

void main() {
  final testOrgId = OrganizationId('org-test-1');
  final testUserId = UserId('user-test-1');
  final testWsId = WorkspaceId('ws-test-1');

  // =========================================================================
  // 1. Intelligence Request & Task Models
  // =========================================================================
  group('1. Intelligence Request & Objective', () {
    test('constructs IntelligenceRequest with typed objective and constraints', () {
      final req = IntelligenceRequest(
        requestId: AnalysisId('req-101'),
        workspaceId: testWsId,
        subject: 'Inflation dynamics 2026',
        objective: const IntelligenceObjective(
          type: 'economic.forecast',
          parameters: {'horizon': 4},
        ),
        scope: const IntelligenceScope(
          geographicEntities: {'ID', 'ASEAN'},
          targetEntities: {'CPI', 'CoreInflation'},
        ),
        constraints: const IntelligenceConstraints(
          minimumConfidence: 0.75,
          requireHumanReview: true,
        ),
        context: IntelligenceContext(
          organizationId: testOrgId,
          userId: testUserId,
          workspaceId: testWsId,
        ),
      );

      expect(req.requestId.value, equals('req-101'));
      expect(req.objective.type, equals('economic.forecast'));
      expect(req.scope.geographicEntities, contains('ID'));
      expect(req.constraints.requireHumanReview, isTrue);
      expect(req.constraints.minimumConfidence, equals(0.75));
    });

    test('IntelligenceResult captures execution outcome, evidence, and artifacts', () {
      final result = IntelligenceResult(
        requestId: AnalysisId('req-101'),
        executionId: ExecutionId('exec-101'),
        success: true,
        summary: 'Forecast finished with expected trajectory.',
        evidence: [
          const Evidence(
            id: EvidenceId('ev-1'),
            type: EvidenceType.statisticalResult,
            source: 'Quarterly Survey',
            reference: 'table_cpi_2026',
          ),
        ],
        artifacts: [
          IntelligenceArtifact(
            id: const ArtifactId('art-1'),
            type: ArtifactType.chart,
            title: 'CPI Forecast Plot',
            metadata: ArtifactMetadata(
              epistemicClass: EpistemicClass.predicted,
              createdAt: DateTime.now(),
            ),
          ),
        ],
      );

      expect(result.success, isTrue);
      expect(result.evidence.length, equals(1));
      expect(result.artifacts.first.metadata.epistemicClass, equals(EpistemicClass.predicted));
    });
  });

  // =========================================================================
  // 2. Planning
  // =========================================================================
  group('2. Intelligence Planning', () {
    test('DefaultIntelligencePlanner produces valid sequential steps', () async {
      const planner = DefaultIntelligencePlanner();
      final req = IntelligenceRequest(
        requestId: AnalysisId('req-201'),
        subject: 'Trade balance analysis',
        objective: const IntelligenceObjective(type: 'trade.balance'),
        context: IntelligenceContext(organizationId: testOrgId),
      );

      final plan = await planner.plan(req);
      expect(plan.steps.length, equals(3));
      expect(plan.steps[0].id, equals('step-data-acquire'));
      expect(plan.steps[1].type, equals('trade.balance'));
      expect(plan.steps[1].dependsOn, contains('step-data-acquire'));
      expect(plan.steps[2].id, equals('step-synthesize'));
    });
  });

  // =========================================================================
  // 3. Execution & Local Runtime
  // =========================================================================
  group('3. Execution & Local Runtime', () {
    test('LocalIntelligenceRuntime executes plan to completion and emits events', () async {
      final runtime = LocalIntelligenceRuntime([
        _TestStepHandler({'acquire_data', 'trade.balance', 'synthesize_findings'}),
      ]);

      final req = IntelligenceRequest(
        requestId: AnalysisId('req-301'),
        subject: 'Commodity market balance',
        objective: const IntelligenceObjective(type: 'trade.balance'),
        context: IntelligenceContext(organizationId: testOrgId),
      );

      const plan = IntelligencePlan(
        planId: 'plan-301',
        steps: [
          IntelligenceStep(id: 's1', type: 'acquire_data'),
          IntelligenceStep(id: 's2', type: 'trade.balance'),
        ],
      );

      final events = <IntelligenceExecutionEvent>[];
      final executionFuture = runtime.start(req, plan);

      // Listen to events
      final execution = await executionFuture;
      runtime.events(execution.executionId).listen(events.add);

      expect(execution.status, equals(IntelligenceExecutionStatus.completed));
      expect(execution.completedAt, isNotNull);
    });
  });

  // =========================================================================
  // 4. Human-in-the-loop Review & Pause / Resume
  // =========================================================================
  group('4. Human Review & Pause / Resume', () {
    test('pauses execution when human review is required and resumes on approval', () async {
      final runtime = LocalIntelligenceRuntime([
        _TestStepHandler({'acquire_data', 'core_eval', 'synthesize_findings'}),
      ]);

      final req = IntelligenceRequest(
        requestId: AnalysisId('req-401'),
        subject: 'High-risk policy recommendation',
        objective: const IntelligenceObjective(type: 'core_eval'),
        constraints: const IntelligenceConstraints(requireHumanReview: true),
        context: IntelligenceContext(organizationId: testOrgId),
      );

      const plan = IntelligencePlan(
        planId: 'plan-401',
        steps: [
          IntelligenceStep(id: 's1', type: 'acquire_data'),
          IntelligenceStep(id: 's2', type: 'core_eval'),
          IntelligenceStep(id: 's3', type: 'synthesize_findings'),
        ],
      );

      final paused = await runtime.start(req, plan);
      expect(paused.status, equals(IntelligenceExecutionStatus.waitingForReview));
      expect(paused.currentStepId, equals('s3'));

      // Resume execution with approval
      final resumed = await runtime.resume(paused.executionId, ReviewDecision.approve);
      expect(resumed.status, equals(IntelligenceExecutionStatus.completed));
      expect(resumed.completedAt, isNotNull);
    });

    test('rejection marks execution as failed', () async {
      final runtime = LocalIntelligenceRuntime([
        _TestStepHandler({'acquire_data', 'synthesize_findings'}),
      ]);

      final req = IntelligenceRequest(
        requestId: AnalysisId('req-402'),
        subject: 'Sensitive synthesis',
        objective: const IntelligenceObjective(type: 'acquire_data'),
        constraints: const IntelligenceConstraints(requireHumanReview: true),
        context: IntelligenceContext(organizationId: testOrgId),
      );

      const plan = IntelligencePlan(
        planId: 'plan-402',
        steps: [
          IntelligenceStep(id: 's1', type: 'acquire_data'),
          IntelligenceStep(id: 's2', type: 'synthesize_findings'),
        ],
      );

      final paused = await runtime.start(req, plan);
      expect(paused.status, equals(IntelligenceExecutionStatus.waitingForReview));

      final failed = await runtime.resume(paused.executionId, ReviewDecision.reject);
      expect(failed.status, equals(IntelligenceExecutionStatus.failed));
      expect(failed.failureReason, contains('Rejected'));
    });

    test('InMemoryHumanReviewService tracks requests and decision lifecycle', () async {
      final service = InMemoryHumanReviewService();
      const req = ReviewRequest(
        executionId: ExecutionId('exec-500'),
        subject: 'Budget allocation',
        reason: 'Large expenditure review',
      );

      await service.submitRequest(req);
      final pending = await service.getPendingRequests();
      expect(pending.length, equals(1));

      final decision = await service.decide(
        request: req,
        decision: ReviewDecision.approve,
        comment: 'Verified with treasury',
        reviewerId: testUserId,
      );

      expect(decision.decision, equals(ReviewDecision.approve));
      expect(decision.reviewerComment, equals('Verified with treasury'));
      expect((await service.getPendingRequests()).isEmpty, isTrue);
    });
  });

  // =========================================================================
  // 5. Knowledge System
  // =========================================================================
  group('5. Knowledge System', () {
    test('InMemoryKnowledgeRepository stores, retrieves, and searches items', () async {
      final repo = InMemoryKnowledgeRepository([
        const KnowledgeItem(
          id: 'k-1',
          title: 'Monetary Policy Framework',
          content: 'Inflation targeting guidelines and interest rate corridor.',
        ),
        const KnowledgeItem(
          id: 'k-2',
          title: 'Fiscal Rules',
          content: 'Statutory debt ceiling at 60% of GDP.',
        ),
      ]);

      final found = await repo.search(const KnowledgeQuery(text: 'inflation'));
      expect(found.length, equals(1));
      expect(found.first.id, equals('k-1'));

      final resolver = DefaultKnowledgeResolver(repo);
      final resolved = await resolver.resolve(
        IntelligenceRequest(
          requestId: AnalysisId('req-k'),
          subject: 'Fiscal',
          objective: const IntelligenceObjective(type: 'eval'),
          context: IntelligenceContext(organizationId: testOrgId),
        ),
      );
      expect(resolved.length, equals(1));
      expect(resolved.first.id, equals('k-2'));
    });

    test('KnowledgeBinding links workspace to knowledge', () {
      final binding = KnowledgeBinding(
        workspaceId: testWsId,
        knowledgeId: 'k-1',
      );
      expect(binding.workspaceId, equals(testWsId));
      expect(binding.knowledgeId, equals('k-1'));
    });
  });

  // =========================================================================
  // 6. Memory System
  // =========================================================================
  group('6. Memory System', () {
    test('InMemoryMemoryStore saves and searches episodic memory', () async {
      final store = InMemoryMemoryStore();
      await store.save(MemoryRecord(
        id: 'mem-1',
        content: 'User prefers quarterly inflation forecasts in percent.',
        createdAt: DateTime.now(),
      ));

      final retrieved = await store.search(const MemoryQuery(text: 'quarterly'));
      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('mem-1'));

      final retriever = DefaultMemoryRetriever(store);
      final results = await retriever.retrieve(const MemoryQuery(text: 'inflation'));
      expect(results.length, equals(1));
    });
  });

  // =========================================================================
  // 7. Evidence & Calibrated Confidence
  // =========================================================================
  group('7. Evidence & Calibrated Confidence', () {
    test('Confidence factors provide inspectable provenance', () {
      const conf = Confidence(
        value: 0.85,
        factors: [
          ConfidenceFactor(
            name: 'Sample size',
            contribution: 0.5,
            explanation: 'N > 5000 records',
          ),
          ConfidenceFactor(
            name: 'Recent source',
            contribution: 0.35,
            explanation: 'Data updated within 7 days',
          ),
        ],
      );

      expect(conf.isHigh, isTrue);
      expect(conf.factors.length, equals(2));
      expect(conf.factors.first.contribution, equals(0.5));
    });

    test('Evidence connects type, source, and reference', () {
      const evidence = Evidence(
        id: EvidenceId('ev-99'),
        type: EvidenceType.calculation,
        source: 'EconometricModelEngine',
        reference: 'ols_regression_step_2',
        confidence: Confidence(value: 0.9),
      );

      expect(evidence.id.value, equals('ev-99'));
      expect(evidence.type, equals(EvidenceType.calculation));
      expect(evidence.confidence?.isHigh, isTrue);
    });
  });

  // =========================================================================
  // 8. Epistemic Classification & Artifacts
  // =========================================================================
  group('8. Epistemic Classification & Artifacts', () {
    test('EpistemicClass distinguishes empirical from predicted data', () {
      expect(EpistemicClass.official.isGrounded, isTrue);
      expect(EpistemicClass.official.isSyntheticOrProjected, isFalse);

      expect(EpistemicClass.predicted.isGrounded, isFalse);
      expect(EpistemicClass.predicted.isSyntheticOrProjected, isTrue);

      expect(EpistemicClass.inferred.isSyntheticOrProjected, isTrue);
    });

    test('IntelligenceArtifact holds structured data and evidence references', () {
      final artifact = IntelligenceArtifact(
        id: const ArtifactId('art-gdp-chart'),
        type: ArtifactType.chart,
        title: 'Projected Growth vs Official Historical',
        data: {'chartType': 'line', 'series': [3.5, 4.1, 5.0]},
        evidenceIds: const [EvidenceId('ev-hist-1'), EvidenceId('ev-proj-2')],
        metadata: ArtifactMetadata(
          epistemicClass: EpistemicClass.simulated,
          createdAt: DateTime.now(),
        ),
      );

      expect(artifact.type, equals(ArtifactType.chart));
      expect(artifact.evidenceIds.length, equals(2));
      expect(artifact.metadata.epistemicClass, equals(EpistemicClass.simulated));
    });
  });

  // =========================================================================
  // 9. Governance & Policies
  // =========================================================================
  group('9. Governance & Policies', () {
    test('IntelligencePolicy evaluates constraints and returns violations', () {
      final policy = _ConfidencePolicy(minRequired: 0.8);

      final req = IntelligenceRequest(
        requestId: AnalysisId('req-pol'),
        subject: 'Test policy',
        objective: const IntelligenceObjective(type: 'test'),
        context: IntelligenceContext(organizationId: testOrgId),
      );

      final passDecision = policy.evaluate(PolicyContext(
        request: req,
        organizationId: testOrgId,
        observedConfidence: 0.85,
      ));
      expect(passDecision.allowed, isTrue);
      expect(passDecision.violations.isEmpty, isTrue);

      final failDecision = policy.evaluate(PolicyContext(
        request: req,
        organizationId: testOrgId,
        observedConfidence: 0.65,
      ));
      expect(failDecision.allowed, isFalse);
      expect(failDecision.violations.length, equals(1));
      expect(failDecision.violations.first.rule, equals('MIN_CONFIDENCE'));
    });
  });

  // =========================================================================
  // 10. Rules System
  // =========================================================================
  group('10. Rules System', () {
    test('Rule evaluates logic independently from authorization', () {
      final rule = _ThresholdRule('growth_rate', threshold: 5.0);

      final result1 = rule.evaluate(const RuleContext({'growth_rate': 6.2}));
      expect(result1.matched, isTrue);

      final result2 = rule.evaluate(const RuleContext({'growth_rate': 3.1}));
      expect(result2.matched, isFalse);
    });
  });

  // =========================================================================
  // 11. Provenance Graph
  // =========================================================================
  group('11. Provenance Graph', () {
    test('ProvenanceGraph tracks links and ancestor dependencies', () {
      const artRef = ProvenanceRef(type: 'artifact', id: 'art-001');
      const evRef = ProvenanceRef(type: 'evidence', id: 'ev-002');
      const execRef = ProvenanceRef(type: 'execution', id: 'exec-003');

      final graph = ProvenanceGraph([
        const ProvenanceLink(from: artRef, relation: 'derivedFrom', to: evRef),
        const ProvenanceLink(from: evRef, relation: 'producedBy', to: execRef),
      ]);

      expect(graph.containsRef(artRef), isTrue);
      expect(graph.containsRef(evRef), isTrue);
      expect(graph.getAncestors(artRef), contains(evRef));
      expect(graph.getOutgoing(artRef).first.relation, equals('derivedFrom'));
      expect(graph.getIncoming(execRef).first.from, equals(evRef));
    });
  });

  // =========================================================================
  // 12. Boundary Invariants
  // =========================================================================
  group('12. Boundary Invariants', () {
    test('package has no domain-specific types and uses generic string types', () {
      const objective = IntelligenceObjective(type: 'domain.custom_task');
      expect(objective.type, isA<String>());

      final artifact = IntelligenceArtifact(
        id: const ArtifactId('art-generic'),
        type: ArtifactType.custom,
        title: 'Generic Output',
        metadata: ArtifactMetadata(
          semanticType: 'mining.mineral_reserve',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      expect(artifact.metadata.semanticType, equals('mining.mineral_reserve'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------
class _TestStepHandler implements IntelligenceStepHandler {
  @override
  final Set<String> supportedTypes;
  _TestStepHandler(this.supportedTypes);

  @override
  Future<void> execute(IntelligenceStep step, IntelligenceState state) async {
    state.set('output_${step.id}', 'done');
  }
}

class _ConfidencePolicy implements IntelligencePolicy {
  @override
  final String id = 'policy-min-confidence';
  final double minRequired;

  _ConfidencePolicy({required this.minRequired});

  @override
  PolicyDecision evaluate(PolicyContext context) {
    final conf = context.observedConfidence ?? 0.0;
    if (conf < minRequired) {
      return PolicyDecision(
        allowed: false,
        violations: [
          PolicyViolation(
            policyId: id,
            rule: 'MIN_CONFIDENCE',
            message: 'Confidence $conf is below required $minRequired',
          ),
        ],
      );
    }
    return const PolicyDecision(allowed: true);
  }
}

class _ThresholdRule implements Rule {
  @override
  final String id = 'rule-threshold';
  final String variableName;
  final double threshold;

  _ThresholdRule(this.variableName, {required this.threshold});

  @override
  RuleResult evaluate(RuleContext context) {
    final val = context.get<double>(variableName) ?? 0.0;
    final matched = val >= threshold;
    return RuleResult(
      matched: matched,
      outputs: {'value': val, 'threshold': threshold},
    );
  }
}

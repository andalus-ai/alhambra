// lib/features/chat/models/chat_entry_entity.dart
import 'dart:convert';

import 'package:objectbox/objectbox.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';

@Entity()
class ChatEntryEntity {
  @Id()
  int id = 0;

  @Index()
  String entryId;

  @Index()
  String sessionId;

  int typeIndex;
  int statusIndex;
  String text;
  bool isLoading;
  int timestamp;

  // ToolCall fields - stored directly in the same table
  String? toolCallId;
  int? toolCallKindIndex;
  String? toolCallSummary;
  String? toolCallDetailInput;
  String? toolCallDetailOutput;
  int? toolCallStatusIndex;
  int? toolCallRiskIndex;
  int? toolCallDurationMs;
  String? toolCallErrorMessage;
  String? toolCallSubtasks; // JSON encoded
  String? toolCallResult; // JSON encoded
  int? toolCallProgress;
  bool? toolCallIsBlocking;

  // ApprovalRequest fields
  String? approvalId;
  String? approvalCommand;
  String? approvalReason;
  int? approvalRiskIndex;
  int? approvalStatusIndex;

  // Plan fields
  String? planTitle;
  String? planSteps; // JSON encoded

  String? errorMessage;
  int? retryCount;

  String? metadataJson;

  String? jobId;
  int? queuePosition;

  ChatEntryEntity({
    this.id = 0,
    required this.entryId,
    required this.sessionId,
    required this.typeIndex,
    required this.statusIndex,
    required this.text,
    this.isLoading = false,
    required this.timestamp,
    this.toolCallId,
    this.toolCallKindIndex,
    this.toolCallSummary,
    this.toolCallDetailInput,
    this.toolCallDetailOutput,
    this.toolCallStatusIndex,
    this.toolCallRiskIndex,
    this.toolCallDurationMs,
    this.toolCallErrorMessage,
    this.toolCallSubtasks,
    this.toolCallResult,
    this.toolCallProgress,
    this.toolCallIsBlocking,
    this.approvalId,
    this.approvalCommand,
    this.approvalReason,
    this.approvalRiskIndex,
    this.approvalStatusIndex,
    this.planTitle,
    this.planSteps,
    this.errorMessage,
    this.retryCount,
    this.metadataJson,
    this.jobId,
    this.queuePosition,
  });

  // Convert from ChatEntry
  factory ChatEntryEntity.fromChatEntry(ChatEntry entry, String sessionId) {
    return ChatEntryEntity(
      entryId: entry.id,
      sessionId: sessionId,
      typeIndex: entry.type.index,
      statusIndex: entry.status.index,
      text: entry.text,
      isLoading: entry.isLoading,
      timestamp: entry.timestamp.millisecondsSinceEpoch,
      toolCallId: entry.toolCall?.id,
      toolCallKindIndex: entry.toolCall?.kind.index,
      toolCallSummary: entry.toolCall?.summary,
      toolCallDetailInput: entry.toolCall?.detailInput,
      toolCallDetailOutput: entry.toolCall?.detailOutput,
      toolCallStatusIndex: entry.toolCall?.status.index,
      toolCallRiskIndex: entry.toolCall?.risk.index,
      toolCallDurationMs: entry.toolCall?.duration?.inMilliseconds,
      toolCallErrorMessage: entry.toolCall?.errorMessage,
      toolCallSubtasks: entry.toolCall?.subtasks != null
          ? jsonEncode(entry.toolCall!.subtasks)
          : null,
      toolCallResult: entry.toolCall?.result != null
          ? jsonEncode(entry.toolCall!.result)
          : null,
      toolCallProgress: entry.toolCall?.progress,
      toolCallIsBlocking: entry.toolCall?.isBlocking,
      approvalId: entry.approval?.id,
      approvalCommand: entry.approval?.command,
      approvalReason: entry.approval?.reason,
      approvalRiskIndex: entry.approval?.risk.index,
      approvalStatusIndex: entry.approval?.status.index,
      planTitle: entry.plan?.title,
      planSteps: entry.plan?.steps != null
          ? jsonEncode(entry.plan!.steps
              .map((s) => {
                    'id': s.id,
                    'description': s.description,
                    'statusIndex': s.status.index,
                  })
              .toList())
          : null,
      errorMessage: entry.errorMessage,
      retryCount: entry.retryCount,
      metadataJson: entry.metadata != null ? jsonEncode(entry.metadata) : null,
      jobId: entry.jobId,
      queuePosition: entry.queuePosition,
    );
  }

  // Convert to ChatEntry
  ChatEntry toChatEntry() {
    ToolCall? toolCall;
    if (toolCallId != null) {
      toolCall = ToolCall(
        id: toolCallId!,
        kind: ToolCallKind.values[toolCallKindIndex ?? 0],
        summary: toolCallSummary ?? '',
        detailInput: toolCallDetailInput,
        detailOutput: toolCallDetailOutput,
        status: ToolCallStatus.values[toolCallStatusIndex ?? 0],
        risk: RiskLevel.values[toolCallRiskIndex ?? 0],
        duration: toolCallDurationMs != null
            ? Duration(milliseconds: toolCallDurationMs!)
            : null,
        errorMessage: toolCallErrorMessage,
        subtasks: toolCallSubtasks != null
            ? List<String>.from(jsonDecode(toolCallSubtasks!))
            : null,
        result: toolCallResult != null
            ? Map<String, dynamic>.from(jsonDecode(toolCallResult!))
            : null,
        progress: toolCallProgress,
        isBlocking: toolCallIsBlocking ?? false,
      );
    }

    ApprovalRequest? approval;
    if (approvalId != null) {
      approval = ApprovalRequest(
        id: approvalId!,
        command: approvalCommand ?? '',
        reason: approvalReason ?? '',
        risk: RiskLevel.values[approvalRiskIndex ?? 0],
        status: ApprovalStatus.values[approvalStatusIndex ?? 0],
      );
    }

    AgentPlan? plan;
    if (planTitle != null && planSteps != null) {
      final stepsData = List<Map<String, dynamic>>.from(jsonDecode(planSteps!));
      final steps = stepsData
          .map((s) => PlanStep(
                id: s['id'],
                description: s['description'],
                status: PlanStepStatus.values[s['statusIndex']],
              ))
          .toList();
      plan = AgentPlan(
        title: planTitle!,
        steps: steps,
      );
    }

    return ChatEntry(
      id: entryId,
      type: ChatEntryType.values[typeIndex],
      status: ChatEntryStatus.values[statusIndex],
      text: text,
      isLoading: isLoading,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      toolCall: toolCall,
      approval: approval,
      plan: plan,
      errorMessage: errorMessage,
      retryCount: retryCount,
      metadata: metadataJson != null
          ? jsonDecode(metadataJson!) as Map<String, dynamic>
          : null,
      jobId: jobId,
      queuePosition: queuePosition,
    );
  }
}

// ─── Attachment Entity ─────────────────────────────────────────────────

// ─── Session Entity ────────────────────────────────────────────────────

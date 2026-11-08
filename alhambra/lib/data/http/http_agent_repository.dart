import 'dart:convert';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';
import 'agent_repository.dart';
import 'api_client.dart';

class HttpAgentRepository implements AgentRepository {
  @override
  Stream<ChatEntry> observeSession(String sessionId) async* {
    final stream = apiClient.sse('/api/v1/sessions/$sessionId/messages/stream');

    await for (final data in stream) {
      final role = (data['role'] as String? ?? '').toUpperCase();
      ChatEntryType type = ChatEntryType.agentText;
      if (role == 'USER') {
        type = ChatEntryType.userPrompt;
      } else if (role == 'SYSTEM') {
        type = ChatEntryType.stepEvent;
      } else if (role == 'TOOL' &&
          (data['toolCalls'] ?? '').toString().isNotEmpty) {
        type = ChatEntryType.toolCall;
      }

      ToolCall? toolCall;
      if (type == ChatEntryType.toolCall) {
        try {
          final decoded = jsonDecode(data['toolCalls'] as String);
          toolCall = ToolCall(
            id: data['id'] as String,
            kind: ToolCallKind.runCommand,
            summary: decoded['summary'] ?? 'Tool Execution',
            detailInput: decoded['input'] as String?,
            detailOutput: decoded['output'] as String?,
            status: ToolCallStatus.success,
            duration: Duration.zero,
          );
        } catch (e) {
          logInfo("Failed to decode tool_calls: $e");
        }
      }

      yield ChatEntry(
        id: data['id'] as String,
        type: type,
        text: data['content'] as String? ?? '',
        toolCall: toolCall,
        status: ChatEntryStatus.completed,
        timestamp: DateTime.timestamp(),
      );
    }
  }
}

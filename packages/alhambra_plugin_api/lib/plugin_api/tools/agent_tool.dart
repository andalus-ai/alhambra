import 'dart:async';
import '../extensions/contribution.dart';

class ToolRequest {
  final String toolId;
  final Map<String, Object?> arguments;
  final String? sessionId;

  const ToolRequest({
    required this.toolId,
    required this.arguments,
    this.sessionId,
  });
}

class ToolResult {
  final bool isSuccess;
  final Object? output;
  final String? error;

  const ToolResult.success(this.output)
      : isSuccess = true,
        error = null;

  const ToolResult.failure(this.error)
      : isSuccess = false,
        output = null;
}

abstract class AgentTool implements OwnedContribution {
  @override
  String get id;

  @override
  String get ownerId;

  String get name;
  String get description;
  Map<String, Object?> get parametersSchema => const {};

  Future<ToolResult> execute(ToolRequest request);
}

import 'dart:convert';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';
import '../rest_backend_service.dart';
import 'grpc_client.dart';
import '../../src/generated/andalus.pb.dart' as grpc;

class GrpcBackendService implements BackendService {
  @override
  Future<List<Project>> listProjects() async {
    final req = grpc.ListProjectsRequest(includeArchived: false);
    final res = await grpcClient.projectClient.listProjects(req);
    return res.projects
        .map((p) => Project(
              id: p.id,
              name: p.name,
              rootPath: p.basePath,
              branch: 'main',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .toList();
  }

  @override
  Future<Project> createProject(
      String name, String description, String basePath) async {
    final req = grpc.CreateProjectRequest(
      name: name,
      description: description,
      basePath: basePath,
    );
    final res = await grpcClient.projectClient.createProject(req);
    return Project(
      id: res.id,
      name: res.name,
      rootPath: res.basePath,
      branch: 'main',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Session>> listSessions(String projectId) async {
    final req = grpc.ListSessionsRequest(projectId: projectId);
    final res = await grpcClient.projectClient.listSessions(req);

    return res.sessions.map((s) {
      SessionStatus parsedStatus;
      switch (s.status.toUpperCase()) {
        case 'RUNNING':
          parsedStatus = SessionStatus.running;
          break;
        case 'DONE':
          parsedStatus = SessionStatus.completed;
          break;
        case 'ERROR':
          parsedStatus = SessionStatus.failed;
          break;
        default:
          parsedStatus = SessionStatus.queued;
      }
      return Session(
        id: s.id,
        projectId: s.projectId,
        title: s.name.isEmpty ? 'Untitled' : s.name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: parsedStatus,
      );
    }).toList();
  }

  @override
  Future<Session> createSession(String projectId, String name) async {
    final req = grpc.CreateSessionRequest(projectId: projectId, name: name);
    final res = await grpcClient.projectClient.createSession(req);
    return Session(
      id: res.id,
      projectId: res.projectId,
      title: res.name.isEmpty ? name : res.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: SessionStatus.queued,
    );
  }

  @override
  Future<Session> forkSession(String sessionId, [String? messageId]) async {
    final req = grpc.ForkSessionRequest(
      sessionId: sessionId,
      messageId: messageId ?? '',
    );
    final res = await grpcClient.projectClient.forkSession(req);
    return Session(
      id: res.id,
      projectId: res.projectId,
      title: res.name.isEmpty ? 'Forked session' : res.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: SessionStatus.queued,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final req = grpc.DeleteSessionRequest(sessionId: sessionId);
    await grpcClient.projectClient.deleteSession(req);
  }

  @override
  Future<Map<String, dynamic>> indexWorkspace(String projectId,
      [String? workspacePath]) async {
    final req = grpc.IndexWorkspaceRequest(
      projectId: projectId,
      workspacePath: workspacePath ?? '',
    );
    final res = await grpcClient.projectClient.indexWorkspace(req);
    return {
      'success': res.success,
      'filesIndexed': res.filesIndexed,
      'symbolsIndexed': res.symbolsIndexed,
      'dependenciesIndexed': res.dependenciesIndexed,
      'durationMs': res.durationMs.toInt(),
      'repositoryHash': res.repositoryHash,
      'error': res.error,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listMessages(String sessionId) async {
    final req = grpc.ListChatMessagesRequest(sessionId: sessionId);
    final res = await grpcClient.chatClient.listMessages(req);
    return res.messages
        .map((msg) => {
              'id': msg.id,
              'role': msg.role,
              'content': msg.content,
            })
        .toList();
  }

  @override
  Future<Map<String, dynamic>> addMessage(String sessionId, String text) async {
    final req = grpc.AddChatMessageRequest(
      sessionId: sessionId,
      role: 'USER',
      content: text,
    );
    final res = await grpcClient.chatClient.addMessage(req);
    return {
      'id': res.id,
      'role': 'USER',
      'content': res.content,
    };
  }

  @override
  Stream<Map<String, dynamic>> runAgent({
    required String sessionId,
    required String prompt,
    String? providerId,
    String? modelId,
    String? workspacePath,
    List<Attachment> attachments = const [],
  }) async* {
    final req = grpc.RunAgentRequest(
      sessionId: sessionId,
      prompt: prompt,
      providerId: providerId ?? '',
      modelId: modelId ?? '',
      workspacePath: workspacePath ?? '',
    );

    try {
      final stream = grpcClient.chatClient.runAgent(req);
      await for (final event in stream) {
        if (event.type == "TEXT") {
          yield {'content': event.content};
        } else if (event.type == "THOUGHT") {
          yield {'channel': 'thinking', 'content': event.content};
        } else if (event.type == "TOOL_CALL") {
          yield {'tool_call': event.content, 'payload': event.payload};
        } else if (event.type == "TOOL_RESULT") {
          yield {'tool_result': event.content, 'payload': event.payload};
        } else if (event.type == "ERROR") {
          yield {'error': event.content};
        } else if (event.type == "DONE") {
          yield {
            'status': SessionStatus.completed.toString(),
            'content': event.content,
          };
        }
      }
    } catch (e) {
      yield {
        'status': SessionStatus.failed.toString(),
        'error': e.toString(),
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listProviders() async {
    final req = grpc.Empty();
    final res = await grpcClient.sdkClient.listProviders(req);
    return res.providers
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'description': p.description,
            })
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listModels(String providerId) async {
    final req = grpc.ListModelsRequest(providerId: providerId);
    final res = await grpcClient.sdkClient.listModels(req);
    return res.models
        .map((m) => {
              'id': m.id,
              'name': m.name,
              'format': m.format,
              'sizeBytes': m.sizeBytes.toInt(),
            })
        .toList();
  }

  @override
  Future<List<String>> listMutations([String? workspacePath]) async {
    // gRPC backend currently unavailable for mutation listing; return empty
    return [];
  }

  @override
  Future<String?> readMutation(String id, [String? workspacePath]) async {
    // gRPC backend currently unavailable for mutation reading
    return null;
  }

  @override
  Stream<Map<String, dynamic>> startAgentRun({
    required String request,
    String? workspacePath,
  }) async* {
    final req = grpc.RunAgentRequest(
      sessionId: 'local-session',
      prompt: request,
      providerId: '',
      modelId: '',
      workspacePath: workspacePath ?? '',
    );

    try {
      final stream = grpcClient.chatClient.runAgent(req);
      await for (final event in stream) {
        // Try to parse payload first (expected JSON string)
        final payload = event.payload;
        Map<String, dynamic>? parsed;
        if (payload.isNotEmpty) {
          try {
            parsed = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          } catch (_) {
            parsed = null;
          }
        }

        if (parsed != null && parsed.containsKey('event')) {
          // Already in {event: 'step'|'done', data: {...}} shape
          yield parsed.map((k, v) => MapEntry(k, v));
        } else if (parsed != null) {
          // No event wrapper; assume it's step data
          yield {'event': 'step', 'data': parsed};
        } else {
          // Fallback mapping based on type
          final type = event.type;
          if (type == 'DONE' || type == 'DONE_EVENT' || type == 'END') {
            yield {'event': 'done'};
          } else if (type == 'STEP' || type == 'STEP_EVENT') {
            // try parsing content as JSON
            try {
              final cont = jsonDecode(event.content) as Map<String, dynamic>;
              yield {'event': 'step', 'data': cont};
            } catch (_) {
              yield {
                'event': 'step',
                'data': {'title': event.content, 'raw': event.payload}
              };
            }
          } else {
            // unknown; forward generically
            yield {
              'event': type,
              'data': {'content': event.content, 'payload': event.payload}
            };
          }
        }
      }
    } catch (e) {
      yield {'event': 'error', 'message': e.toString()};
    }
  }

  final RestBackendService _restBackend = RestBackendService();

  @override
  Future<List<Map<String, dynamic>>> listSkills(
      {String? category, String? query, bool includeTrash = false}) async {
    try {
      final req = grpc.ListSkillsRequest(
        category: category ?? '',
        query: query ?? '',
        includeTrash: includeTrash,
      );
      final res = await grpcClient.skillClient.listSkills(req);
      return res.skills
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'description': s.description,
                'category': s.category,
                'reasoning_mode': s.reasoningMode,
                'mutates_workspace': s.mutatesWorkspace,
                'allowed_tools': s.allowedTools,
                'source_path': s.sourcePath,
                'in_trash': s.inTrash,
              })
          .toList();
    } catch (_) {
      return _restBackend.listSkills(
          category: category, query: query, includeTrash: includeTrash);
    }
  }

  @override
  Future<Map<String, dynamic>> getSkill(String id) async {
    try {
      final req = grpc.GetSkillRequest(skillId: id);
      final res = await grpcClient.skillClient.getSkill(req);
      final s = res.skill;
      return {
        'info': {
          'id': s.info.id,
          'name': s.info.name,
          'description': s.info.description,
          'category': s.info.category,
          'reasoning_mode': s.info.reasoningMode,
          'mutates_workspace': s.info.mutatesWorkspace,
          'allowed_tools': s.info.allowedTools,
          'source_path': s.info.sourcePath,
          'in_trash': s.info.inTrash,
        },
        'instructions': s.instructions,
        'references': s.references,
        'scripts': s.scripts,
        'raw_markdown': s.rawMarkdown,
      };
    } catch (_) {
      return _restBackend.getSkill(id);
    }
  }

  @override
  Future<Map<String, dynamic>> createSkill(Map<String, dynamic> data) async {
    try {
      final req = grpc.SaveSkillRequest(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        category: data['category'] ?? '',
        reasoningMode: data['reasoning_mode'] ?? '',
        mutatesWorkspace: data['mutates_workspace'] == true,
        allowedTools: List<String>.from(data['allowed_tools'] ?? []),
        instructions: data['instructions'] ?? '',
      );
      final res = await grpcClient.skillClient.saveSkill(req);
      return {
        'success': res.success,
        'skill_id': res.skillId,
        'message': res.message
      };
    } catch (_) {
      return _restBackend.createSkill(data);
    }
  }

  @override
  Future<Map<String, dynamic>> updateSkill(
      String id, Map<String, dynamic> data) async {
    final merged = Map<String, dynamic>.from(data);
    merged['id'] = id;
    return createSkill(merged);
  }

  @override
  Future<void> deleteSkill(String id, {bool hard = false}) async {
    try {
      final req = grpc.DeleteSkillRequest(skillId: id, hardDelete: hard);
      await grpcClient.skillClient.deleteSkill(req);
    } catch (_) {
      await _restBackend.deleteSkill(id, hard: hard);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedSkills() async {
    try {
      final res = await grpcClient.skillClient.listTrash(grpc.Empty());
      return res.skills
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'description': s.description,
                'category': s.category,
                'in_trash': s.inTrash,
              })
          .toList();
    } catch (_) {
      return _restBackend.listTrashedSkills();
    }
  }

  @override
  Future<void> restoreSkill(String id) async {
    try {
      final req = grpc.RestoreSkillRequest(skillId: id);
      await grpcClient.skillClient.restoreSkill(req);
    } catch (_) {
      await _restBackend.restoreSkill(id);
    }
  }

  @override
  Future<void> reloadSkills() async {
    try {
      await grpcClient.skillClient.reloadSkills(grpc.Empty());
    } catch (_) {
      await _restBackend.reloadSkills();
    }
  }
}

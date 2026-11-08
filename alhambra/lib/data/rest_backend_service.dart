import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';
import 'backend_service.dart';

class RestBackendService implements BackendService {
  // In-memory data store for missing backend endpoints
  final List<Project> _projects = [];
  final List<Session> _sessions = [];
  final Map<String, List<Map<String, dynamic>>> _messages = {};
  final _uuid = const Uuid();

  RestBackendService() {
    // Seed initial project so UI isn't completely empty
    _projects.add(Project(
      id: 'default-proj',
      name: 'Default Workspace',
      rootPath: '/tmp/default',
      branch: 'main',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    _sessions.add(Session(
      id: 'default-session',
      projectId: 'default-proj',
      title: 'Initial Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: SessionStatus.completed,
    ));
    _messages['default-session'] = [];
  }

  @override
  Future<List<Project>> listProjects() async {
    return List.from(_projects);
  }

  @override
  Future<Project> createProject(
      String name, String description, String basePath) async {
    final p = Project(
      id: _uuid.v4(),
      name: name,
      rootPath: basePath.isNotEmpty ? basePath : '/tmp/$name',
      branch: 'main',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _projects.add(p);
    return p;
  }

  @override
  Future<List<Session>> listSessions(String projectId) async {
    return _sessions.where((s) => s.projectId == projectId).toList();
  }

  @override
  Future<Session> createSession(String projectId, String name) async {
    final s = Session(
      id: _uuid.v4(),
      projectId: projectId,
      title: name,
      status: SessionStatus.completed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessions.add(s);
    _messages[s.id] = [];
    return s;
  }

  @override
  Future<Session> forkSession(String sessionId, [String? messageId]) async {
    final original = _sessions.firstWhere((s) => s.id == sessionId);
    final s = Session(
      id: _uuid.v4(),
      projectId: original.projectId,
      title: '${original.title} (Fork)',
      status: SessionStatus.completed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessions.add(s);
    final allMsgs = _messages[sessionId] ?? [];
    if (messageId != null) {
      final idx = allMsgs.indexWhere((m) => m['id'] == messageId);
      if (idx != -1) {
        _messages[s.id] = List.from(allMsgs.sublist(0, idx + 1));
      } else {
        _messages[s.id] = List.from(allMsgs);
      }
    } else {
      _messages[s.id] = List.from(allMsgs);
    }
    return s;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _messages.remove(sessionId);
  }

  @override
  Future<Map<String, dynamic>> indexWorkspace(String projectId,
      [String? workspacePath]) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'success': true,
      'filesIndexed': 12,
      'symbolsIndexed': 48,
      'dependenciesIndexed': 16,
      'durationMs': 120,
      'repositoryHash': 'mock-hash-12-48',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listMessages(String sessionId) async {
    return List.from(_messages[sessionId] ?? []);
  }

  @override
  Future<Map<String, dynamic>> addMessage(String sessionId, String text) async {
    final msg = {
      'id': _uuid.v4(),
      'role': 'USER',
      'content': text.trim(),
    };
    _messages.putIfAbsent(sessionId, () => []).add(msg);
    return msg;
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
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 1));

    yield {
      'content':
          'I have received your request: "$prompt". I am a mock agent simulating a response.',
      'status': SessionStatus.completed.toString(),
      'toolCalls': [
        {
          'id': _uuid.v4(),
          'kind': 'runCommand',
          'summary': 'Simulated command',
          'detailInput': 'echo "Hello world"',
          'detailOutput': 'Hello world',
          'risk': 'safe',
          'duration': 500,
        }
      ]
    };
  }

  @override
  Stream<Map<String, dynamic>> startAgentRun(
      {required String request, String? workspacePath}) async* {
    // Simulated agent run: emit step updates as maps
    final now = DateTime.now();
    List<Map<String, dynamic>> steps = [
      {
        'id': 's1',
        'type': 'analysis',
        'status': 'pending',
        'title': 'Analyze repository',
        'description': 'Scanning for auth flow',
        'startedAt': now.toIso8601String(),
      },
      {
        'id': 's2',
        'type': 'fileRead',
        'status': 'pending',
        'title': 'Read SessionService.java',
        'description': 'Open file to inspect auth logic',
        'startedAt': now.toIso8601String(),
      },
      {
        'id': 's3',
        'type': 'fileWrite',
        'status': 'pending',
        'title': 'Modify SessionService.java',
        'description': 'Make session lookup null-safe',
        'startedAt': now.toIso8601String(),
      },
      {
        'id': 's4',
        'type': 'test',
        'status': 'pending',
        'title': 'Run tests',
        'description': 'Execute unit test suite',
        'startedAt': now.toIso8601String(),
      },
      {
        'id': 's5',
        'type': 'verification',
        'status': 'pending',
        'title': 'Verify changes',
        'description': 'Check that failing tests are resolved',
        'startedAt': now.toIso8601String(),
      },
    ];

    // emit planning snapshot
    for (var s in steps) {
      yield {'event': 'step', 'data': s};
    }

    // run steps with delays
    for (var s in steps) {
      await Future.delayed(const Duration(milliseconds: 500));
      var running = Map.of(s);
      running['status'] = 'running';
      yield {'event': 'step', 'data': running};

      await Future.delayed(const Duration(milliseconds: 800));
      var completed = Map.of(s);
      completed['status'] = s['type'] == 'test' ? 'failed' : 'completed';
      completed['completedAt'] = DateTime.now().toIso8601String();
      completed['durationMs'] = 1000;
      yield {'event': 'step', 'data': completed};

      if (s['type'] == 'test') {
        // emit inspect and retry steps
        await Future.delayed(const Duration(milliseconds: 300));
        var inspect = {
          'id': '${s['id']}-inspect',
          'type': 'analysis',
          'status': 'pending',
          'title': 'Inspect failures',
          'description': 'Analyze failing tests',
          'startedAt': DateTime.now().toIso8601String(),
        };
        yield {'event': 'step', 'data': inspect};
        await Future.delayed(const Duration(milliseconds: 400));
        inspect['status'] = 'completed';
        inspect['completedAt'] = DateTime.now().toIso8601String();
        yield {'event': 'step', 'data': inspect};

        var retry = {
          'id': '${s['id']}-retry',
          'type': 'fileWrite',
          'status': 'running',
          'title': 'Adjust implementation',
          'description': 'Fix failing assertion',
          'startedAt': DateTime.now().toIso8601String(),
        };
        yield {'event': 'step', 'data': retry};
        await Future.delayed(const Duration(milliseconds: 600));
        retry['status'] = 'completed';
        retry['completedAt'] = DateTime.now().toIso8601String();
        yield {'event': 'step', 'data': retry};

        var rerun = {
          'id': '${s['id']}-rerun',
          'type': 'test',
          'status': 'running',
          'title': 'Run tests (iteration 2)',
          'description': 'Run test suite again',
          'startedAt': DateTime.now().toIso8601String(),
        };
        yield {'event': 'step', 'data': rerun};
        await Future.delayed(const Duration(milliseconds: 800));
        rerun['status'] = 'completed';
        rerun['completedAt'] = DateTime.now().toIso8601String();
        yield {'event': 'step', 'data': rerun};
      }
    }

    // done
    yield {'event': 'done'};
  }

  @override
  Future<List<Map<String, dynamic>>> listProviders() async {
    for (final port in [8085, 8080]) {
      try {
        final res = await http
            .get(Uri.parse('http://127.0.0.1:$port/api/v1/providers'));
        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [
      {'id': 'gollek', 'name': 'Gollek Local Engine'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listModels(String providerId) async {
    for (final port in [8085, 8080]) {
      try {
        final res = await http.get(Uri.parse(
            'http://127.0.0.1:$port/api/v1/models?provider=$providerId'));
        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [
      {
        'id': 'hf:unsloth/gemma-4-12b-it-GGUF',
        'name': 'gemma-4-12b-it-GGUF',
        'format': 'gguf'
      },
    ];
  }

  @override
  Future<List<String>> listMutations([String? workspacePath]) async {
    final path = workspacePath ?? '/';
    try {
      final dir = Uri.file('$path/.alhambra/mutations');
      // Using dart:io is avoided in web builds; this is for desktop/mobile.
      final d = Directory.fromUri(dir);
      if (!await d.exists()) return [];
      final files = await d.list().toList();
      return files
          .where((f) => f is File && f.path.endsWith('.record'))
          .map((f) => f.path.split('/').last.replaceAll('.record', ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String?> readMutation(String id, [String? workspacePath]) async {
    final path = workspacePath ?? '/';
    try {
      final file = File('$path/.alhambra/mutations/$id.record');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<String> _getBaseUrl() async {
    for (final port in [8085, 8080]) {
      try {
        final res = await http
            .get(Uri.parse('http://127.0.0.1:$port/api/v1/providers'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          return 'http://127.0.0.1:$port/api/v1';
        }
      } catch (_) {}
    }
    return 'http://127.0.0.1:8080/api/v1'; // fallback
  }

  @override
  Future<List<Map<String, dynamic>>> listSkills(
      {String? category, String? query, bool includeTrash = false}) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/skills').replace(queryParameters: {
      if (category != null) 'category': category,
      if (query != null) 'query': query,
      if (includeTrash) 'includeTrash': 'true',
    });
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('skills')) {
          return List<Map<String, dynamic>>.from(decoded['skills']);
        } else if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getSkill(String id) async {
    final baseUrl = await _getBaseUrl();
    final res = await http.get(Uri.parse('$baseUrl/skills/$id'));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load skill: ${res.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> createSkill(Map<String, dynamic> data) async {
    final baseUrl = await _getBaseUrl();
    final res = await http.post(
      Uri.parse('$baseUrl/skills'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to create skill: ${res.body}');
  }

  @override
  Future<Map<String, dynamic>> updateSkill(
      String id, Map<String, dynamic> data) async {
    final baseUrl = await _getBaseUrl();
    final res = await http.put(
      Uri.parse('$baseUrl/skills/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to update skill: ${res.body}');
  }

  @override
  Future<void> deleteSkill(String id, {bool hard = false}) async {
    final baseUrl = await _getBaseUrl();
    final uri = Uri.parse('$baseUrl/skills/$id').replace(queryParameters: {
      if (hard) 'hard': 'true',
    });
    final res = await http.delete(uri);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete skill: ${res.body}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedSkills() async {
    final baseUrl = await _getBaseUrl();
    try {
      final res = await http.get(Uri.parse('$baseUrl/skills/trash'));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('skills')) {
          return List<Map<String, dynamic>>.from(decoded['skills']);
        } else if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  @override
  Future<void> restoreSkill(String id) async {
    final baseUrl = await _getBaseUrl();
    final res = await http.post(Uri.parse('$baseUrl/skills/$id/restore'));
    if (res.statusCode != 200) {
      throw Exception('Failed to restore skill: ${res.body}');
    }
  }

  @override
  Future<void> reloadSkills() async {
    final baseUrl = await _getBaseUrl();
    final res = await http.post(Uri.parse('$baseUrl/skills/reload'));
    if (res.statusCode != 200) {
      throw Exception('Failed to reload skills: ${res.body}');
    }
  }
}

import 'package:mocktail/mocktail.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';
import 'package:alhambra/data/backend_service.dart';

/// Mock implementation of [BackendService] for unit tests.
/// No real network calls are made — all responses are configured with `when(...)`.
class MockBackendService extends Mock implements BackendService {}

/// Stub data helpers — single source of truth for expected shapes.
class TestData {
  static final List<Map<String, dynamic>> providers = [
    {'id': 'gollek', 'name': 'Gollek Local', 'description': 'Local models'},
    {'id': 'openai', 'name': 'OpenAI', 'description': 'OpenAI API models'},
    {
      'id': 'claude',
      'name': 'Anthropic Claude',
      'description': 'Anthropic API models'
    },
    {
      'id': 'andalus-pro',
      'name': 'Andalus Pro',
      'description': 'Pro cloud models'
    },
  ];

  static final List<Map<String, dynamic>> gollekModels = [
    {
      'id': 'llama-3-8b',
      'name': 'Llama 3 8B',
      'format': 'gguf',
      'sizeBytes': 0
    },
    {
      'id': 'mistral-7b',
      'name': 'Mistral 7B',
      'format': 'gguf',
      'sizeBytes': 0
    },
  ];

  static final List<Map<String, dynamic>> openaiModels = [
    {'id': 'gpt-4o', 'name': 'GPT-4 Omni', 'format': '', 'sizeBytes': 0},
    {
      'id': 'gpt-3.5-turbo',
      'name': 'GPT-3.5 Turbo',
      'format': '',
      'sizeBytes': 0
    },
  ];

  static final List<Project> projects = [
    Project(
        id: 'proj-1',
        name: 'Andalus Platform',
        rootPath: '/workspace/andalus',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()),
    Project(
        id: 'proj-2',
        name: 'Alhambra GUI',
        rootPath: '/workspace/alhambra',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()),
  ];

  static final List<Session> sessions = [
    Session(
      id: 'sess-1',
      projectId: 'proj-1',
      title: 'Implement gRPC service',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: SessionStatus.completed,
    ),
    Session(
      id: 'sess-2',
      projectId: 'proj-1',
      title: 'Fix provider list',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: SessionStatus.running,
    ),
  ];
}

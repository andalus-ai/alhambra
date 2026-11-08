// ignore_for_file: avoid_print
import 'package:grpc/grpc.dart';
import 'package:alhambra/src/generated/andalus.pbgrpc.dart';

void main() async {
  final channel = ClientChannel(
    '127.0.0.1',
    port: 9000,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  final sdkClient = SdkServiceClient(channel);
  final projectClient = ProjectServiceClient(channel);
  final chatClient = ChatServiceClient(channel);

  try {
    print("Requesting providers...");
    final res = await sdkClient.listProviders(Empty());
    print("Success: ${res.providers.length} providers");
    for (var p in res.providers) {
      print("- ${p.name}");
    }

    print("\nCreating project...");
    final pRes = await projectClient.createProject(CreateProjectRequest(
        name: 'Test Project', description: 'Test', basePath: '/tmp'));
    print("Created project: ${pRes.id}");

    print("\nCreating session...");
    final sRes = await projectClient.createSession(
        CreateSessionRequest(projectId: pRes.id, name: 'Test Session'));
    print("Created session: ${sRes.id}");

    print("\nRunning agent with gollek / unsloth/gemma-4-12b-it-GGUF...");
    final stream = chatClient.runAgent(RunAgentRequest(
      sessionId: sRes.id,
      prompt: 'inspect current project',
      providerId: 'gollek',
      modelId: 'unsloth/gemma-4-12b-it-GGUF',
      workspacePath: '/tmp',
    ));
    await for (final event in stream) {
      print("Event: ${event.type} -> ${event.content}");
    }
    print("Agent run complete!");
  } catch (e) {
    print("Error: $e");
  }
  await channel.shutdown();
}

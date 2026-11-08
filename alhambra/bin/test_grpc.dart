// ignore_for_file: avoid_print
import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:alhambra/src/generated/andalus.pbgrpc.dart';

Future<void> main() async {
  final channel = ClientChannel(
    '127.0.0.1',
    port: 9000,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  final projectClient = ProjectServiceClient(channel);

  print('Calling listProjects on gRPC port 9000...');
  try {
    final res = await projectClient.listProjects(ListProjectsRequest());
    print('Received ${res.projects.length} projects:');
    for (final p in res.projects) {
      print('• Project [${p.id}]: ${p.name} (${p.basePath})');
    }
  } catch (e) {
    print('Error: ${e.toString()}');
  }

  await channel.shutdown();
}

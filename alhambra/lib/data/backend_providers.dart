import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'backend_service.dart';
import 'grpc/grpc_backend_service.dart';
import 'rest_backend_service.dart';
import 'agent_repository.dart';
import 'grpc/grpc_agent_repository.dart';
import 'http_agent_repository.dart';

enum BackendProtocol {
  grpc,
  rest,
}

extension BackendProtocolExtension on BackendProtocol {
  String get displayName {
    switch (this) {
      case BackendProtocol.grpc:
        return 'gRPC (Port 9000)';
      case BackendProtocol.rest:
        return 'REST (Port 8080)';
    }
  }
}

/// Toggles between gRPC and REST. Defaults to gRPC as requested.
class BackendProtocolNotifier extends StateNotifier<BackendProtocol> {
  BackendProtocolNotifier() : super(BackendProtocol.grpc);

  void setProtocol(BackendProtocol protocol) {
    state = protocol;
  }
}

final backendProtocolProvider =
    StateNotifierProvider<BackendProtocolNotifier, BackendProtocol>(
  (ref) => BackendProtocolNotifier(),
);

/// Provides the correct [BackendService] implementation based on the active protocol.
final backendServiceProvider = Provider<BackendService>((ref) {
  final protocol = ref.watch(backendProtocolProvider);
  if (protocol == BackendProtocol.grpc) {
    return GrpcBackendService();
  } else {
    return RestBackendService();
  }
});

/// Provides the correct [AgentRepository] for SSE vs gRPC streaming.
final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  final protocol = ref.watch(backendProtocolProvider);
  if (protocol == BackendProtocol.grpc) {
    return GrpcAgentRepository();
  } else {
    return HttpAgentRepository();
  }
});

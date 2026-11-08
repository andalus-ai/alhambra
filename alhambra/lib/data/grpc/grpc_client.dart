import 'package:grpc/grpc.dart';
import '../../src/generated/andalus.pbgrpc.dart';

class TenantInterceptor implements ClientInterceptor {
  @override
  ResponseFuture<R> interceptUnary<Q, R>(ClientMethod<Q, R> method, Q request,
      CallOptions options, ClientUnaryInvoker<Q, R> invoker) {
    final newOptions = options
        .mergedWith(CallOptions(metadata: {'x-tenant-id': 'default-tenant'}));
    return invoker(method, request, newOptions);
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
      ClientMethod<Q, R> method,
      Stream<Q> requests,
      CallOptions options,
      ClientStreamingInvoker<Q, R> invoker) {
    final newOptions = options
        .mergedWith(CallOptions(metadata: {'x-tenant-id': 'default-tenant'}));
    return invoker(method, requests, newOptions);
  }
}

class GrpcClient {
  static final GrpcClient _instance = GrpcClient._internal();
  factory GrpcClient() => _instance;

  String currentHost = '127.0.0.1';
  int currentPort = 9000;

  late ClientChannel channel;
  late ProjectServiceClient projectClient;
  late ApiKeyServiceClient apiClient;
  late TaskServiceClient taskClient;
  late ChatServiceClient chatClient;
  late SdkServiceClient sdkClient;
  late McpServiceClient mcpClient;
  late MemoryServiceClient memoryClient;
  late SkillServiceClient skillClient;

  GrpcClient._internal() {
    _initChannel(currentHost, currentPort);
  }

  void configure({String host = '127.0.0.1', int port = 9000}) {
    if (currentHost == host && currentPort == port) return;
    currentHost = host;
    currentPort = port;
    try {
      channel.shutdown();
    } catch (_) {}
    _initChannel(host, port);
  }

  void _initChannel(String host, int port) {
    channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    final tenantInterceptor = TenantInterceptor();
    projectClient =
        ProjectServiceClient(channel, interceptors: [tenantInterceptor]);
    apiClient = ApiKeyServiceClient(channel, interceptors: [tenantInterceptor]);
    taskClient = TaskServiceClient(channel, interceptors: [tenantInterceptor]);
    chatClient = ChatServiceClient(channel, interceptors: [tenantInterceptor]);
    sdkClient = SdkServiceClient(channel, interceptors: [tenantInterceptor]);
    mcpClient = McpServiceClient(channel, interceptors: [tenantInterceptor]);
    memoryClient =
        MemoryServiceClient(channel, interceptors: [tenantInterceptor]);
    skillClient =
        SkillServiceClient(channel, interceptors: [tenantInterceptor]);
  }
}

final grpcClient = GrpcClient();

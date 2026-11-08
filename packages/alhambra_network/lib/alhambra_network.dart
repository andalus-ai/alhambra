/// Alhambra Network — transport-neutral HTTP, WebSocket, SSE, gRPC contracts,
/// authentication propagation, composable interceptors, retry, and timeout policies.
///
/// Pure Dart. No Flutter. No domain semantics.
library alhambra_network;

// Request
export 'src/request/request_method.dart';
export 'src/request/network_request.dart';

// Response
export 'src/response/network_response.dart';
export 'src/response/network_error.dart';

// Authentication
export 'src/authentication/auth_token.dart';
export 'src/authentication/auth_token_provider.dart';

// Interceptors
export 'src/interceptor/network_interceptor.dart';
export 'src/interceptor/auth_interceptor.dart';
export 'src/interceptor/logging_interceptor.dart';

// Retry
export 'src/retry/retry_policy.dart';

// Timeout
export 'src/timeout/timeout_policy.dart';

// Client
export 'src/client/network_client.dart';
export 'src/client/mock_network_client.dart';

// WebSocket
export 'src/websocket/websocket_client.dart';

// SSE
export 'src/sse/sse_client.dart';

// gRPC
export 'src/grpc/grpc_client.dart';

/// Thin gRPC abstraction — actual protobuf/generated clients live in consuming packages.
abstract interface class GrpcClient {
  /// Performs a unary RPC.
  Future<TResponse> unary<TRequest, TResponse>(
    String service,
    String method,
    TRequest request,
  );

  /// Performs a server-streaming RPC.
  Stream<TResponse> serverStream<TRequest, TResponse>(
    String service,
    String method,
    TRequest request,
  );
}

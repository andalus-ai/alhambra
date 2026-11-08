/// Platform-wide request context that flows through API, application services,
/// and execution engines. Provides contextual trace, tenant, and identity metadata.
final class RequestContext {
  final String requestId;
  final String? correlationId;
  final String? causationId;
  final String? principalId;
  final String? organizationId;
  final String? workspaceId;
  final String? traceId;

  const RequestContext({
    required this.requestId,
    this.correlationId,
    this.causationId,
    this.principalId,
    this.organizationId,
    this.workspaceId,
    this.traceId,
  });

  @override
  String toString() =>
      'RequestContext(requestId: $requestId, corr: $correlationId, trace: $traceId)';
}

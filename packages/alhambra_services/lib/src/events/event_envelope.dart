/// Platform event envelope carrying correlation, causation, and tenancy metadata.
final class EventEnvelope {
  final String eventId;
  final String eventType;
  final DateTime occurredAt;
  final String? correlationId;
  final String? causationId;
  final String? organizationId;
  final String? actorId;
  final Map<String, Object?> payload;

  const EventEnvelope({
    required this.eventId,
    required this.eventType,
    required this.occurredAt,
    this.correlationId,
    this.causationId,
    this.organizationId,
    this.actorId,
    this.payload = const {},
  });

  @override
  String toString() =>
      'EventEnvelope($eventId: $eventType, corr: $correlationId, cause: $causationId)';
}

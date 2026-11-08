/// Generic contract for domain events emitted by any Alhambra module or entity.
abstract interface class DomainEvent {
  /// Unique event type string (e.g. 'workspace.created', 'execution.step_completed').
  String get type;

  /// UTC timestamp of when the domain occurrence took place.
  DateTime get occurredAt;
}

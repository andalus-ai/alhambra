import 'composition_contracts.dart';

/// Immutable filters for reading lifecycle diagnostics from a durable store.
///
/// [from] and [to] are inclusive UTC time bounds. [before] is an exclusive
/// upper bound intended for keyset-style pagination. Results are returned in
/// ascending timestamp order; implementations should use a stable secondary
/// key when timestamps are equal.
final class CompositionLifecycleEventQuery {
  final String? correlationId;
  final String? ownerId;
  final CompositionLifecycleOperation? operation;
  final CompositionLifecycleStatus? status;
  final DateTime? from;
  final DateTime? to;
  final DateTime? before;
  final int limit;

  CompositionLifecycleEventQuery({
    this.correlationId,
    this.ownerId,
    this.operation,
    this.status,
    this.from,
    this.to,
    this.before,
    this.limit = 100,
  }) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    if (from != null && to != null && from!.isAfter(to!)) {
      throw ArgumentError('The from bound must not be after the to bound.');
    }
  }
}

/// Storage port for append-only composition lifecycle diagnostics.
///
/// Implementations belong in persistence adapters, not in the composition
/// API. [append] should complete only after the event has been accepted by
/// the adapter's durability boundary. Adapters may buffer writes, but must
/// document their flush and shutdown guarantees. A store should preserve the
/// original event fields and must not rewrite timestamps or correlation IDs.
///
/// Query results must be ordered oldest-first and respect [query]'s filters
/// and limit. The runtime's bounded in-memory history remains independent:
/// configuring a store does not imply that the runtime blocks lifecycle
/// callbacks on storage I/O.
abstract interface class CompositionLifecycleEventStore {
  Future<void> append(CompositionLifecycleEvent event);

  Future<List<CompositionLifecycleEvent>> query(
    CompositionLifecycleEventQuery query,
  );
}

import 'plugin_revocation_journal.dart';
import 'plugin_revocation_operator_actions.dart';
import 'plugin_revocation_outbox.dart';

/// Maximum page size accepted by scoped revocation inspection.
const int pluginRevocationMaxPageSize = 200;

/// Shared, validated bounds for a database-native scoped query.
///
/// [cursor] is opaque to the runtime. A durable adapter must authenticate it
/// and bind it to the exact scope, query family, normalized filters and
/// snapshot boundary. It must reject a cursor issued for any other query.
sealed class PluginRevocationScopedQuery {
  final String scopeId;
  final DateTime? fromInclusive;
  final DateTime? toExclusive;
  final int pageSize;
  final String? cursor;

  PluginRevocationScopedQuery({
    required this.scopeId,
    this.fromInclusive,
    this.toExclusive,
    this.pageSize = 50,
    this.cursor,
  }) {
    if (scopeId.trim().isEmpty) {
      throw ArgumentError.value(scopeId, 'scopeId', 'Must not be empty.');
    }
    if (pageSize < 1 || pageSize > pluginRevocationMaxPageSize) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and $pluginRevocationMaxPageSize.',
      );
    }
    if (fromInclusive != null &&
        toExclusive != null &&
        !fromInclusive!.isBefore(toExclusive!)) {
      throw ArgumentError('fromInclusive must be earlier than toExclusive.');
    }
    if (cursor != null &&
        (cursor!.isEmpty || cursor!.length > 4096)) {
      throw ArgumentError.value(cursor, 'cursor', 'Invalid opaque cursor.');
    }
  }
}

/// Query for journal entries, ordered by (updatedAt DESC, idempotencyKey DESC).
final class PluginRevocationJournalPageQuery
    extends PluginRevocationScopedQuery {
  final Set<PluginRevocationJournalStatus> statuses;

  PluginRevocationJournalPageQuery({
    required super.scopeId,
    super.fromInclusive,
    super.toExclusive,
    super.pageSize,
    super.cursor,
    Set<PluginRevocationJournalStatus> statuses = const {},
  }) : statuses = Set.unmodifiable(statuses);
}

/// Query for outbox messages, ordered by (occurredAt DESC, eventId DESC).
final class PluginRevocationOutboxPageQuery
    extends PluginRevocationScopedQuery {
  final Set<PluginRevocationOutboxState> states;

  PluginRevocationOutboxPageQuery({
    required super.scopeId,
    super.fromInclusive,
    super.toExclusive,
    super.pageSize,
    super.cursor,
    Set<PluginRevocationOutboxState> states = const {},
  }) : states = Set.unmodifiable(states);
}

/// Query for operator actions, ordered by (occurredAt DESC, actionId DESC).
final class PluginRevocationOperatorActionPageQuery
    extends PluginRevocationScopedQuery {
  PluginRevocationOperatorActionPageQuery({
    required super.scopeId,
    super.fromInclusive,
    super.toExclusive,
    super.pageSize,
    super.cursor,
  });
}

/// Immutable page returned by a scoped query adapter.
///
/// [snapshotAt] is a ceiling on the ordering timestamp, not a stable insertion
/// snapshot. Late-arriving rows with backdated timestamps may become visible
/// during traversal. Strict audit exports need a transaction or export job.
/// [nextCursor] is null on the final page.
final class PluginRevocationScopedPage<T> {
  final List<T> items;
  final String? nextCursor;
  final DateTime snapshotAt;

  PluginRevocationScopedPage({
    required Iterable<T> items,
    required this.nextCursor,
    required DateTime snapshotAt,
  })  : items = List.unmodifiable(items),
        snapshotAt = snapshotAt.toUtc() {
    if (nextCursor != null &&
        (nextCursor!.isEmpty || nextCursor!.length > 4096)) {
      throw ArgumentError.value(nextCursor, 'nextCursor');
    }
  }

  bool get hasMore => nextCursor != null;
}

/// Optional database-native query capability for revocation inspection.
///
/// Implementations MUST apply scope, time, status/state, snapshot and cursor
/// predicates in SQL before LIMIT. They MUST use bound parameters and a total
/// deterministic order. They MUST NOT implement these methods by calling
/// readAll/readAllOutbox/readOperatorActions and filtering in memory.
///
/// Cursor tokens are adapter-issued opaque values bound to the complete
/// normalized query. A cursor reused with a different scope, query family,
/// filter, time range or page size must be rejected.
abstract interface class PluginRevocationScopedQueryStore {
  Future<PluginRevocationScopedPage<PluginRevocationJournalEntry>>
      queryJournalPage(PluginRevocationJournalPageQuery query);

  Future<PluginRevocationScopedPage<PluginRevocationOutboxMessage>>
      queryOutboxPage(PluginRevocationOutboxPageQuery query);

  Future<PluginRevocationScopedPage<PluginRevocationOperatorAction>>
      queryOperatorActionPage(PluginRevocationOperatorActionPageQuery query);
}

/// Raised when an adapter cannot safely interpret an opaque continuation.
final class PluginRevocationInvalidCursorException implements Exception {
  final String message;

  const PluginRevocationInvalidCursorException([
    this.message = 'The continuation cursor is invalid for this query.',
  ]);

  @override
  String toString() => message;
}

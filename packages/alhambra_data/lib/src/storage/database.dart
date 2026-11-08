/// Transaction handle for database operations.
abstract interface class DatabaseTransaction {
  Future<List<Map<String, Object?>>> query(
    String query, {
    Map<String, Object?> parameters = const {},
  });

  Future<void> execute(
    String query, {
    Map<String, Object?> parameters = const {},
  });
}

/// Generic database contract for structured relational or document storage.
abstract interface class Database {
  Future<void> open();

  Future<void> close();

  Future<List<Map<String, Object?>>> query(
    String query, {
    Map<String, Object?> parameters = const {},
  });

  Future<void> execute(
    String query, {
    Map<String, Object?> parameters = const {},
  });

  Future<T> transaction<T>(
    Future<T> Function(DatabaseTransaction tx) action,
  );
}

/// In-memory mock database implementing [Database] and [DatabaseTransaction].
final class InMemoryDatabase implements Database, DatabaseTransaction {
  bool _isOpen = false;
  final List<String> executedStatements = [];
  final Map<String, List<Map<String, Object?>>> cannedQueryResponses = {};

  bool get isOpen => _isOpen;

  @override
  Future<void> open() async {
    _isOpen = true;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<void> execute(
    String query, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!_isOpen) throw StateError('Database is not open');
    executedStatements.add(query);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String query, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!_isOpen) throw StateError('Database is not open');
    return cannedQueryResponses[query] ?? const [];
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseTransaction tx) action,
  ) async {
    if (!_isOpen) throw StateError('Database is not open');
    return await action(this);
  }
}

import '../result/result.dart';

/// Marker interface for read-only query operations without side-effects.
abstract interface class Query<TResponse> {}

/// Contract for asynchronous query execution handlers.
abstract interface class QueryHandler<TQuery extends Query<TResponse>, TResponse> {
  Future<Result<TResponse>> handle(TQuery query);
}

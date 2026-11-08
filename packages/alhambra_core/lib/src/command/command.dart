import '../result/result.dart';

/// Marker interface for operations that mutate state or produce side-effects.
abstract interface class Command<TResponse> {}

/// Contract for asynchronous command execution handlers.
abstract interface class CommandHandler<TCommand extends Command<TResponse>, TResponse> {
  Future<Result<TResponse>> handle(TCommand command);
}

import 'reactive_context_contracts.dart';

/// Abstract interface for a contribution context.
abstract interface class ContributionContext {
  /// The ID of the target.
  String get targetId;
  /// The values of the context.
  Map<String, Object?> get data;

  /// Returns the value for the given context key.
  T? get<T>(ContextKey<T> key);
  T? getRaw<T>(String key);
}

/// Base implementation of [ContributionContext].
class BaseContributionContext implements ContributionContext {
  /// The ID of the target.
  @override
  final String targetId;

  /// The values of the context.
  @override
  final Map<String, Object?> data;

  /// Creates a new [BaseContributionContext] instance.
  const BaseContributionContext({
    required this.targetId,
    this.data = const {},
  });

  /// Returns the value for the given context key.
  @override
  T? get<T>(ContextKey<T> key) {
    final val = data[key.id];
    if (val is T) return val;
    return null;
  }

  /// Returns the value for the given context key.
  @override
  T? getRaw<T>(String key) {
    final val = data[key];
    if (val is T) return val;
    return null;
  }
}

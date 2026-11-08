import '../error/alhambra_error.dart';

/// Sealed functional Result type representing either a [Success] value or a [Failure] error.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with [value].
  const factory Result.success(T value) = Success<T>;

  /// Creates a failed result with [error].
  const factory Result.failure(AlhambraError error) = Failure<T>;

  /// Returns true if this instance is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns true if this instance is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Unwraps the value if success, or returns null if failure.
  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        Failure<T>() => null,
      };

  /// Unwraps the error if failure, or returns null if success.
  AlhambraError? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(error: final err) => err,
      };

  /// Transforms the value of a [Success] using [transform], leaving [Failure] unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(value: final v) => Result<R>.success(transform(v)),
        Failure<T>(error: final err) => Result<R>.failure(err),
      };

  /// Pattern-matches over the result.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AlhambraError error) onFailure,
  }) =>
      switch (this) {
        Success<T>(value: final v) => onSuccess(v),
        Failure<T>(error: final err) => onFailure(err),
      };
}

/// Successful branch of a [Result].
final class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Failed branch of a [Result].
final class Failure<T> extends Result<T> {
  final AlhambraError error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

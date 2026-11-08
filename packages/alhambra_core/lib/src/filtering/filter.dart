import 'package:meta/meta.dart';

/// Supported comparison operations for filtering queries.
enum FilterOperator {
  equals,
  notEquals,
  contains,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  isIn,
  isNotIn,
  isNull,
  isNotNull,
}

/// A single declarative predicate constraint applied to a resource field.
@immutable
final class Filter {
  /// Field or attribute name (e.g. 'status', 'ownerId', 'createdAt').
  final String field;

  /// Comparison operator.
  final FilterOperator operator;

  /// Value to compare against (may be null for isNull/isNotNull).
  final Object? value;

  const Filter({
    required this.field,
    required this.operator,
    this.value,
  });

  const Filter.equals(this.field, this.value)
      : operator = FilterOperator.equals;

  const Filter.contains(this.field, String this.value)
      : operator = FilterOperator.contains;

  const Filter.isIn(this.field, List<Object> this.value)
      : operator = FilterOperator.isIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Filter &&
          runtimeType == other.runtimeType &&
          other.field == field &&
          other.operator == operator &&
          other.value == value;

  @override
  int get hashCode => Object.hash(field, operator, value);

  @override
  String toString() => 'Filter($field ${operator.name} $value)';
}

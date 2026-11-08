import 'contribution_context.dart';

/// Strongly typed context key for UI evaluation.
final class ContextKey<T> {
  final String id;

  const ContextKey(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ContextKey<$T>($id)';
}

/// Standard core context keys.
abstract final class ContextKeys {
  static const workspaceOpen = ContextKey<bool>('workspace.open');
  static const activeView = ContextKey<String?>('workbench.activeView');
  static const editorActive = ContextKey<bool>('editor.active');
  static const selectionCount = ContextKey<int>('selection.count');
  static const activeWorkspaceId = ContextKey<String?>('workspace.activeId');
  static const isProLicensed = ContextKey<bool>('license.isPro');
  static const activeLanguage = ContextKey<String?>('editor.language');
}

/// Immutable snapshot of context values at a specific revision.
class ContextSnapshot implements ContributionContext {
  final int revision;
  @override
  final String targetId;
  final Map<String, Object?> values;

  const ContextSnapshot({
    this.revision = 0,
    this.targetId = '',
    this.values = const {},
  });

  const ContextSnapshot.empty({
    this.revision = 0,
    this.targetId = '',
  }) : values = const {};

  @override
  Map<String, Object?> get data => values;

  @override
  T? get<T>(ContextKey<T> key) {
    final val = values[key.id];
    if (val is T) return val;
    return null;
  }

  @override
  T? getRaw<T>(String key) {
    final val = values[key];
    if (val is T) return val;
    return null;
  }

  bool contains<T>(ContextKey<T> key) => values.containsKey(key.id);

  ContextSnapshot merge(ContextSnapshot other) {
    return ContextSnapshot(
      revision: revision >= other.revision ? revision + 1 : other.revision + 1,
      targetId: targetId.isNotEmpty ? targetId : other.targetId,
      values: {
        ...values,
        ...other.values,
      },
    );
  }
}

/// Notification of a changed context key.
final class ContextChange<T> {
  final ContextKey<T> key;
  final T? previous;
  final T? current;

  const ContextChange({
    required this.key,
    this.previous,
    this.current,
  });
}

/// Interface for reading context values.
abstract interface class UiContext {
  T? read<T>(ContextKey<T> key);
  T readRequired<T>(ContextKey<T> key);
  ContextSnapshot snapshot();
}

/// AST hierarchy for declarative, indexable condition expressions.
sealed class ContextCondition {
  const ContextCondition();

  Set<ContextKey<dynamic>> dependencies();
  bool evaluate(UiContext context);
}

final class EqualsCondition<T> extends ContextCondition {
  final ContextKey<T> key;
  final T expected;

  const EqualsCondition(this.key, this.expected);

  @override
  Set<ContextKey<dynamic>> dependencies() => {key};

  @override
  bool evaluate(UiContext context) {
    final val = context.read(key);
    return val == expected;
  }
}

final class NotEqualsCondition<T> extends ContextCondition {
  final ContextKey<T> key;
  final T unexpected;

  const NotEqualsCondition(this.key, this.unexpected);

  @override
  Set<ContextKey<dynamic>> dependencies() => {key};

  @override
  bool evaluate(UiContext context) {
    final val = context.read(key);
    return val != unexpected;
  }
}

final class ExistsCondition<T> extends ContextCondition {
  final ContextKey<T> key;

  const ExistsCondition(this.key);

  @override
  Set<ContextKey<dynamic>> dependencies() => {key};

  @override
  bool evaluate(UiContext context) {
    return context.read(key) != null;
  }
}

final class AndCondition extends ContextCondition {
  final List<ContextCondition> conditions;

  const AndCondition(this.conditions);

  @override
  Set<ContextKey<dynamic>> dependencies() =>
      conditions.expand((c) => c.dependencies()).toSet();

  @override
  bool evaluate(UiContext context) =>
      conditions.every((c) => c.evaluate(context));
}

final class OrCondition extends ContextCondition {
  final List<ContextCondition> conditions;

  const OrCondition(this.conditions);

  @override
  Set<ContextKey<dynamic>> dependencies() =>
      conditions.expand((c) => c.dependencies()).toSet();

  @override
  bool evaluate(UiContext context) =>
      conditions.any((c) => c.evaluate(context));
}

final class NotCondition extends ContextCondition {
  final ContextCondition condition;

  const NotCondition(this.condition);

  @override
  Set<ContextKey<dynamic>> dependencies() => condition.dependencies();

  @override
  bool evaluate(UiContext context) => !condition.evaluate(context);
}

/// Interface for storing and dispatching context modifications.
abstract interface class ContextStore implements UiContext {
  void set<T>(ContextKey<T> key, T value);
  void remove<T>(ContextKey<T> key);
  Stream<ContextChange<dynamic>> changes();
}

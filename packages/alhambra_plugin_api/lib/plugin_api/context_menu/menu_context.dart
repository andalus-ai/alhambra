import '../context/contribution_context.dart';

/// Represents the context for a menu contribution.
class MenuContext extends BaseContributionContext {
  /// Creates a new [MenuContext] instance.
  const MenuContext({
    required super.targetId,
    super.data = const {},
  });
}

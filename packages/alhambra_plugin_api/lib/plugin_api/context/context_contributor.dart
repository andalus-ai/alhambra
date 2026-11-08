import '../extensions/contribution.dart';
import 'context_builder.dart';

/// Interface for contributing to the context.
abstract interface class ContextContributor {
  /// Contributes to the context.
  void contribute(ContextWriter writer);
}

/// A contribution to the context.
class ContextContribution implements OwnedContribution {
  /// The ID of the contribution.
  @override
  final String id;

  /// The ID of the owner.
  @override
  final String ownerId;

  /// The function to contribute to the context.
  final void Function(ContextWriter writer) contribute;

  /// Creates a new [ContextContribution] instance.
  const ContextContribution({
    required this.id,
    required this.ownerId,
    required this.contribute,
  });
}

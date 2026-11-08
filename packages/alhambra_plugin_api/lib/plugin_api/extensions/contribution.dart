
/// Interface for owned contributions.
abstract interface class OwnedContribution {
  /// Globally unique contribution ID.
  String get id;

  /// Module/plugin responsible for this contribution.
  String get ownerId;
}

/// Interface for owner cleanup.
abstract interface class OwnerCleanup {
  /// Unregister all contributions for a given owner.
  void unregisterAllForOwner(String ownerId);
}

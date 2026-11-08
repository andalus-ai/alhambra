import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

import 'contribution_registry.dart';

class ContributionScope {
  final String ownerId;

  const ContributionScope({required this.ownerId});

  void register<T extends OwnedContribution>(
    ContributionRegistry<T> registry,
    T contribution,
  ) {
    if (contribution.ownerId != ownerId) {
      throw StateError(
        'Contribution owner "${contribution.ownerId}" must match current module "$ownerId".',
      );
    }

    registry.register(contribution);
  }
}

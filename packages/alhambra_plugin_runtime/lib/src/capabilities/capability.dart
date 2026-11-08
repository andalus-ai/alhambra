import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

///
class CapabilityContribution implements OwnedContribution {
  @override
  final String id;

  @override
  final String ownerId;

  final String description;

  const CapabilityContribution({
    required this.id,
    required this.ownerId,
    this.description = '',
  });
}

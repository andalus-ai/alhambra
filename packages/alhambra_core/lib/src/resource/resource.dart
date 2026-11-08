import 'resource_metadata.dart';

/// Contract for domain entities that carry standard Alhambra [ResourceMetadata].
abstract interface class Resource {
  ResourceMetadata get metadata;
}
